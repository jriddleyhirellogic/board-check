import socket
import argparse
import os
import time
import struct
import subprocess
import sys
import dpkt
from collections import defaultdict
from queue import Queue
from threading import Thread, Lock

# ----------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------
#UDP_IP = "10.101.15.195"
UDP_IP = "10.101.48.53"
# UDP_IP = "0.0.0.0"
UDP_PORT = 35121
BUFFER_SIZE = 65536
REQUIRED_BUFFER_SIZE = 268435456  # 256 MB

# ----- Image geometry --------------------------------------------------
WIDTH = 4512
HEIGHT = 4581
LANES = 8
ROW_PADDING = 16
PACKETS_PER_LINE = 5

# ----- Packet format ---------------------------------------------------
HEADER_SIZE = 2          # Start marker (2 bytes)
SEQ_LINE_SIZE = 2        # Line sequence number (2 bytes)
SEQ_PACKET_SIZE = 2      # Packet sequence number (2 bytes)
TOTAL_HEADER = HEADER_SIZE + SEQ_LINE_SIZE + SEQ_PACKET_SIZE  # 6 bytes total

# ----- Sequence number base (0 or 1) -----------------------------------
SEQ_START = 0  # Change to 1 when you update the sender

# ----- Packet reordering -----------------------------------------------
PACKET_WAIT_TIME = 0.01  # Wait 10ms for late packets before filling with zeros
FRAME_TIMEOUT = 2.0      # Maximum time to wait for a complete frame (seconds)
LINE_BATCH_SIZE = 10     # Number of lines to accumulate before writing

# ----- Output -----------------------------------------------------------
RAW_DIR = "raw_frames"
os.makedirs(RAW_DIR, exist_ok=True)

# Global frame counter
frame_counter = 0

# Track total processed UDP payload bytes (after removing header)
total_payload_bytes = 0

# Packet loss tracking
packet_loss_stats = {
    'total_packets': 0,
    'expected_packets': 0,
    'lost_packets': 0,
    'out_of_order': 0,
    'filled_with_zeros': 0
}
stats_lock = Lock()

# Debug mode flag
DEBUG_MODE = False

# ----------------------------------------------------------------------
def check_udp_buffer_limits():
    """Check system UDP receive buffer limits and exit if too low."""
    print("[INIT] Checking UDP receive buffer limits...")
    
    try:
        # Check rmem_max
        result_max = subprocess.run(['sysctl', 'net.core.rmem_max'], 
                                   capture_output=True, text=True, check=True)
        rmem_max = int(result_max.stdout.strip().split('=')[1].strip())
        
        # Check rmem_default
        result_default = subprocess.run(['sysctl', 'net.core.rmem_default'], 
                                       capture_output=True, text=True, check=True)
        rmem_default = int(result_default.stdout.strip().split('=')[1].strip())
        
        print(f"[INIT] Current net.core.rmem_max: {rmem_max:,} bytes")
        print(f"[INIT] Current net.core.rmem_default: {rmem_default:,} bytes")
        print(f"[INIT] Required minimum: {REQUIRED_BUFFER_SIZE:,} bytes")
        
        # Check if either is below required size
        if rmem_max < REQUIRED_BUFFER_SIZE or rmem_default < REQUIRED_BUFFER_SIZE:
            print("\n" + "="*70)
            print("[ERROR] UDP receive buffer limits are too low!")
            print("="*70)
            print(f"\nRequired: {REQUIRED_BUFFER_SIZE:,} bytes ({REQUIRED_BUFFER_SIZE//1024//1024} MB)")
            print(f"Current rmem_max: {rmem_max:,} bytes ({rmem_max//1024//1024} MB)")
            print(f"Current rmem_default: {rmem_default:,} bytes ({rmem_default//1024//1024} MB)")
            print("\nTo increase the limits, run these commands:\n")
            print(f"  sudo sysctl -w net.core.rmem_max={REQUIRED_BUFFER_SIZE}")
            print(f"  sudo sysctl -w net.core.rmem_default={REQUIRED_BUFFER_SIZE}")
            print("\nTo make these changes persistent across reboots, add to /etc/sysctl.conf:")
            print(f"  net.core.rmem_max = {REQUIRED_BUFFER_SIZE}")
            print(f"  net.core.rmem_default = {REQUIRED_BUFFER_SIZE}")
            print("="*70 + "\n")
            sys.exit(1)
        
        print("[INIT] Buffer limits OK ✓\n")
        
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to check buffer limits: {e}")
        print("[WARNING] Proceeding anyway, but you may experience packet loss")
        print(f"[WARNING] Consider running with sudo or setting buffer limits manually\n")
    except Exception as e:
        print(f"[ERROR] Unexpected error checking buffer limits: {e}")
        print("[WARNING] Proceeding anyway\n")

# ----------------------------------------------------------------------
def parse_udp_packet(packet):
    if len(packet) < 20:
        return None
    
    ihl = (packet[0] & 0x0F) * 4
    protocol = packet[9]
    if protocol != 17:
        return None
    
    src_ip = socket.inet_ntoa(packet[12:16])
    if len(packet) < ihl + 8:
        return None
    
    udp_header = packet[ihl:ihl+8]
    src_port = struct.unpack('!H', udp_header[0:2])[0]
    dst_port = struct.unpack('!H', udp_header[2:4])[0]
    udp_payload = packet[ihl+8:]
    
    return (src_ip, src_port, dst_port, udp_payload)

# ----------------------------------------------------------------------
def extract_sequence_numbers(data):
    """Extract line and packet sequence numbers from packet header.
    
    Returns: (line_seq, packet_seq, payload) or (None, None, None) if invalid
    """
    if len(data) < TOTAL_HEADER:
        return None, None, None
    
    # Skip first 2 bytes (start marker)
    line_seq = struct.unpack('!H', data[HEADER_SIZE:HEADER_SIZE+SEQ_LINE_SIZE])[0]
    packet_seq = struct.unpack('!H', data[HEADER_SIZE+SEQ_LINE_SIZE:TOTAL_HEADER])[0]
    payload = data[TOTAL_HEADER:]

    # Only print in debug mode
    if DEBUG_MODE:
        print(f"Line: {line_seq}, Packet: {packet_seq}")
    
    return line_seq, packet_seq, payload

# ----------------------------------------------------------------------
class FrameBuffer:
    """Buffers packets and writes them in order, filling missing packets with zeros.
    Uses background thread for file I/O to avoid blocking packet reception."""
    
    def __init__(self, frame_num, raw_filename):
        self.frame_num = frame_num
        self.raw_filename = raw_filename
        
        # Open file with large buffer (64MB)
        self.file = open(raw_filename, 'wb', buffering=64*1024*1024)
        self.start_time = time.time()
        
        # Buffer: lines[line_num][packet_num] = (payload, timestamp)
        self.lines = defaultdict(dict)
        self.next_line_to_write = SEQ_START
        self.bytes_written = 0
        self.packet_count = 0
        
        # Determine expected packet payload size from first packet
        self.expected_payload_size = None
        
        # Background writer thread
        self.write_queue = Queue(maxsize=1000)
        self.writing = True
        self.writer_thread = Thread(target=self._writer_thread, daemon=True)
        self.writer_thread.start()
        
        # Stats
        self.local_filled_zeros = 0
        self.local_lost_packets = 0
    
    def _writer_thread(self):
        """Background thread that handles all file writes."""
        while True:  # Changed from: while self.writing
            try:
                item = self.write_queue.get(timeout=0.1)
                if item is None:  # Poison pill - this is our exit signal
                    break
                
                line_data, line_num, missing_packets = item
                
                # Write all payloads for this line
                for payload in line_data:
                    self.file.write(payload)
                    self.bytes_written += len(payload)
                
                # Log if there were missing packets (only in debug mode)
                if DEBUG_MODE and missing_packets:
                    print(f"[FILL] Line {line_num}: filled packets {sorted(missing_packets)} with zeros")
                
                # Mark task as done
                self.write_queue.task_done()
                        
            except Exception as e:
                # Only log errors if we haven't received poison pill
                if DEBUG_MODE:
                    print(f"[WRITER] Exception: {e}")
                continue
    
    def add_packet(self, line_seq, packet_seq, payload):
        """Add a packet to the buffer."""
        self.lines[line_seq][packet_seq] = (payload, time.time())
        self.packet_count += 1
        
        if self.expected_payload_size is None:
            self.expected_payload_size = len(payload)
    
    def try_write_complete_lines(self, force=False):
        """Write all complete lines that are ready.
        Uses batching to reduce write frequency."""
        
        # Don't write too frequently unless forced
        if not force and len(self.lines) < LINE_BATCH_SIZE:
            return
        
        current_time = time.time()
        lines_queued = 0
        
        while True:
            line_num = self.next_line_to_write
            
            # Check if we have any packets for this line
            if line_num not in self.lines:
                # No packets yet - check if we should wait or skip
                if line_num == SEQ_START:
                    # Still waiting for first line
                    break
                
                # Check if we have packets from future lines (meaning we missed this line)
                has_future_lines = any(l > line_num for l in self.lines.keys())
                if has_future_lines:
                    oldest_future_packet = min(
                        min(ts for payload, ts in packets.values())
                        for line, packets in self.lines.items() if line > line_num
                    )
                    if current_time - oldest_future_packet > PACKET_WAIT_TIME:
                        # Fill entire line with zeros
                        self._queue_line_with_zeros(line_num)
                        self.next_line_to_write += 1
                        lines_queued += 1
                        continue
                break
            
            line_packets = self.lines[line_num]
            
            # Check if line is complete or if we should give up waiting
            oldest_packet_time = min(ts for _, ts in line_packets.values())
            waited_long_enough = (current_time - oldest_packet_time) > PACKET_WAIT_TIME
            
            expected_packets = set(range(SEQ_START, SEQ_START + PACKETS_PER_LINE))
            received_packets = set(line_packets.keys())
            missing_packets = expected_packets - received_packets
            
            if not missing_packets or waited_long_enough:
                # Queue this line for writing (filling missing packets with zeros)
                self._queue_line(line_num, line_packets, missing_packets)
                del self.lines[line_num]
                self.next_line_to_write += 1
                lines_queued += 1
            else:
                # Still waiting for packets
                break
        
        return lines_queued
    
    def _queue_line(self, line_num, packets, missing_packets):
        """Queue a complete line for background writing, filling missing packets with zeros."""
        line_data = []
        
        for packet_num in range(SEQ_START, SEQ_START + PACKETS_PER_LINE):
            if packet_num in packets:
                payload, _ = packets[packet_num]
                line_data.append(payload)
            else:
                # Fill with zeros
                zero_payload = b'\x00' * self.expected_payload_size
                line_data.append(zero_payload)
                self.local_filled_zeros += 1
        
        # Queue for background write
        self.write_queue.put((line_data, line_num, missing_packets))
    
    def _queue_line_with_zeros(self, line_num):
        """Queue an entire line filled with zeros (when no packets received)."""
        line_data = [b'\x00' * self.expected_payload_size for _ in range(PACKETS_PER_LINE)]
        self.local_filled_zeros += PACKETS_PER_LINE
        self.local_lost_packets += PACKETS_PER_LINE
        
        if DEBUG_MODE:
            print(f"[FILL] Line {line_num}: entire line filled with zeros (no packets received)")
        
        self.write_queue.put((line_data, line_num, set()))
    
    def finalize(self, force=False):
        """Finalize frame, writing any remaining buffered lines."""
        
        # DEBUG: Show what's in the buffer
        if self.lines:
            buffered_lines = sorted(self.lines.keys())
        
        expected_last_line = SEQ_START + HEIGHT - 1
        
        if force:
            # Write ALL remaining lines from next_line_to_write to expected_last_line
            lines_queued = 0
            for line_num in range(self.next_line_to_write, expected_last_line + 1):
                if line_num in self.lines:
                    # Line has some packets - write what we have, fill missing with zeros
                    expected_packets = set(range(SEQ_START, SEQ_START + PACKETS_PER_LINE))
                    received_packets = set(self.lines[line_num].keys())
                    missing_packets = expected_packets - received_packets
                    self._queue_line(line_num, self.lines[line_num], missing_packets)
                    lines_queued += 1
                else:
                    # Line completely missing - fill entire line with zeros
                    self._queue_line_with_zeros(line_num)
                    lines_queued += 1
            
            # Clear the buffer
            self.lines.clear()
            self.next_line_to_write = expected_last_line + 1
        
        # Use join() to wait for all tasks to complete
        self.write_queue.join()
        
        # Now send poison pill to stop the writer thread
        self.writing = False  # Set flag (though not used anymore)
        self.write_queue.put(None)  # Poison pill
        self.writer_thread.join(timeout=10.0)
        
        # Update global stats
        with stats_lock:
            packet_loss_stats['filled_with_zeros'] += self.local_filled_zeros
            packet_loss_stats['lost_packets'] += self.local_lost_packets
        
        self.file.close()
        elapsed = time.time() - self.start_time
        
        return elapsed, self.bytes_written, self.packet_count
    
    def is_complete(self):
        """Check if frame has received all expected packets."""
        expected_packets = HEIGHT * PACKETS_PER_LINE
        expected_last_line = SEQ_START + HEIGHT - 1
        
        # Must have all packets AND either:
        # 1. Have written past the last line, OR
        # 2. Have the last line in buffer
        has_all_packets = self.packet_count >= expected_packets
        has_last_line_data = (self.next_line_to_write > expected_last_line or 
                            expected_last_line in self.lines)
        
        return has_all_packets and has_last_line_data

    def is_timed_out(self):
        """Check if frame has exceeded timeout."""
        return (time.time() - self.start_time) > FRAME_TIMEOUT

# ----------------------------------------------------------------------
def compute_expected_frame_size():
    """Calculate expected frame size including row padding."""
    packed_row_bytes = WIDTH * 3 // 2
    return HEIGHT * (packed_row_bytes + ROW_PADDING)

expected_frame_size = compute_expected_frame_size()

# ----------------------------------------------------------------------
def process_packet(line_seq, packet_seq, payload, current_frame):
    """Common packet processing logic used by both live and pcap modes.
    
    Returns: (current_frame, frame_completed)
    """
    global frame_counter, total_payload_bytes
    
    with stats_lock:
        total_payload_bytes += len(payload)
        packet_loss_stats['total_packets'] += 1
    
    # Start new frame if needed
    if current_frame is None:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        raw_filename = os.path.join(RAW_DIR, f"frame_{frame_counter:06d}_{timestamp}.raw")
        current_frame = FrameBuffer(frame_counter, raw_filename)
        print(f"[RX] Starting frame {frame_counter}...")
    
    # Add packet to buffer
    current_frame.add_packet(line_seq, packet_seq, payload)
    
    # Try to write complete lines (with batching)
    current_frame.try_write_complete_lines(force=False)
    
    frame_completed = False
    
    # Check if frame is complete or timed out
    if current_frame.is_complete():
        elapsed_rx, bytes_written, packet_count = current_frame.finalize(force=True)
        
        expected_packets = HEIGHT * PACKETS_PER_LINE
        with stats_lock:
            packet_loss_stats['expected_packets'] += expected_packets
        
        print(f"[RX] Frame {frame_counter} saved ({bytes_written:,} bytes)")
        print(f"     Packets: {packet_count}/{expected_packets}")
        print(f"     Filled with zeros: {current_frame.local_filled_zeros} packets")
        print(f"     File: {current_frame.raw_filename}\n")
        
        frame_counter += 1
        frame_completed = True
        current_frame = None
    elif current_frame.is_timed_out():
        elapsed_rx, bytes_written, packet_count = current_frame.finalize(force=True)
        
        expected_packets = HEIGHT * PACKETS_PER_LINE
        with stats_lock:
            packet_loss_stats['expected_packets'] += expected_packets
        
        print(f"[TIMEOUT] Frame {frame_counter} incomplete after {FRAME_TIMEOUT}s - forcing finalization")
        print(f"          Bytes written: {bytes_written:,} / {expected_frame_size:,}")
        print(f"          Packets: {packet_count}/{expected_packets}")
        print(f"          Filled with zeros: {current_frame.local_filled_zeros} packets")
        print(f"          File: {current_frame.raw_filename}\n")
        
        frame_counter += 1
        frame_completed = True
        current_frame = None
    
    return current_frame, frame_completed

# ----------------------------------------------------------------------
def pcap_reader(pcap_file):
    """Read packets from a pcap file and process them."""
    global frame_counter, total_payload_bytes, packet_loss_stats
    
    print(f"[PCAP MODE] Reading from: {pcap_file}")
    print(f"[CONFIG] Sequence numbers start from: {SEQ_START}")
    print(f"[CONFIG] Packet wait time: {PACKET_WAIT_TIME*1000:.1f}ms")
    print(f"[CONFIG] Frame timeout: {FRAME_TIMEOUT}s")
    print(f"[CONFIG] Line batch size: {LINE_BATCH_SIZE}")
    print(f"[CONFIG] Debug mode: {'ON' if DEBUG_MODE else 'OFF'}\n")
    
    try:
        with open(pcap_file, 'rb') as f:
            pcap = dpkt.pcap.Reader(f)
            
            current_frame = None
            packet_count = 0
            udp_packet_count = 0
            valid_packet_count = 0
            
            for timestamp, buf in pcap:
                packet_count += 1
                
                # Parse Ethernet frame
                try:
                    eth = dpkt.ethernet.Ethernet(buf)
                except:
                    continue
                
                # Check if it's an IP packet
                if not isinstance(eth.data, dpkt.ip.IP):
                    continue
                
                ip = eth.data
                
                # Check if it's UDP
                if not isinstance(ip.data, dpkt.udp.UDP):
                    continue
                
                udp = ip.data
                udp_packet_count += 1
                
                # Filter by port
                if udp.dport != UDP_PORT:
                    continue
                
                # Extract sequence numbers and payload
                line_seq, packet_seq, payload = extract_sequence_numbers(udp.data)
                if line_seq is None:
                    continue
                
                valid_packet_count += 1
                
                # Process the packet
                current_frame, frame_completed = process_packet(
                    line_seq, packet_seq, payload, current_frame
                )
            
            # Finalize any remaining frame
            if current_frame:
                print(f"[PCAP] End of file reached - finalizing current frame...")
                current_frame.finalize(force=True)
            
            print(f"\n[PCAP] Processing complete")
            print(f"[PCAP] Total packets in file: {packet_count:,}")
            print(f"[PCAP] UDP packets: {udp_packet_count:,}")
            print(f"[PCAP] Valid data packets (port {UDP_PORT}): {valid_packet_count:,}")
            print(f"\n[STATS] Total UDP payload bytes processed: {total_payload_bytes:,} bytes")
            print(f"[STATS] Total packets received: {packet_loss_stats['total_packets']:,}")
            print(f"[STATS] Packets filled with zeros: {packet_loss_stats['filled_with_zeros']}")
            print(f"[STATS] Out of order packets: {packet_loss_stats['out_of_order']}")
            print(f"[STATS] Estimated lost packets: {packet_loss_stats['lost_packets']}")
            
    except FileNotFoundError:
        print(f"[ERROR] File not found: {pcap_file}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Failed to read pcap file: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

# ----------------------------------------------------------------------
def udp_receiver_raw():
    global frame_counter, total_payload_bytes, packet_loss_stats
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_UDP)
    except PermissionError:
        print("[ERROR] Raw sockets require root privileges!")
        return
    
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 64 * 1024 * 1024)
    sock.bind((UDP_IP, 0))
    
    print(f"[RAW SOCKET MODE] Listening on {UDP_IP} (all UDP ports)")
    print(f"[CONFIG] Sequence numbers start from: {SEQ_START}")
    print(f"[CONFIG] Packet wait time: {PACKET_WAIT_TIME*1000:.1f}ms")
    print(f"[CONFIG] Frame timeout: {FRAME_TIMEOUT}s")
    print(f"[CONFIG] Line batch size: {LINE_BATCH_SIZE}")
    print(f"[CONFIG] File buffer: 64MB")
    print(f"[CONFIG] Debug mode: {'ON' if DEBUG_MODE else 'OFF'}\n")
    
    current_frame = None
    
    while True:
        try:
            packet, addr = sock.recvfrom(BUFFER_SIZE)
            parsed = parse_udp_packet(packet)
            if parsed is None:
                continue
            
            src_ip, src_port, dst_port, udp_payload = parsed
            if dst_port != UDP_PORT:
                continue
            
            line_seq, packet_seq, payload = extract_sequence_numbers(udp_payload)
            if line_seq is None:
                continue
            
            # Process the packet
            current_frame, frame_completed = process_packet(
                line_seq, packet_seq, payload, current_frame
            )
            
        except KeyboardInterrupt:
            print("\n[STOP] Interrupted by user")
            if current_frame:
                current_frame.finalize(force=True)
            print(f"\n[STATS] Total UDP payload bytes processed: {total_payload_bytes:,} bytes")
            print(f"[STATS] Total packets received: {packet_loss_stats['total_packets']:,}")
            print(f"[STATS] Packets filled with zeros: {packet_loss_stats['filled_with_zeros']}")
            print(f"[STATS] Out of order packets: {packet_loss_stats['out_of_order']}")
            print(f"[STATS] Estimated lost packets: {packet_loss_stats['lost_packets']}")
            break

# ----------------------------------------------------------------------
def udp_receiver_normal():
    global frame_counter, total_payload_bytes, packet_loss_stats
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 64 * 1024 * 1024)
    sock.bind((UDP_IP, UDP_PORT))
    
    print(f"Listening on {UDP_IP}:{UDP_PORT}")
    print(f"[CONFIG] Sequence numbers start from: {SEQ_START}")
    print(f"[CONFIG] Packet wait time: {PACKET_WAIT_TIME*1000:.1f}ms")
    print(f"[CONFIG] Frame timeout: {FRAME_TIMEOUT}s")
    print(f"[CONFIG] Line batch size: {LINE_BATCH_SIZE}")
    print(f"[CONFIG] File buffer: 64MB")
    print(f"[CONFIG] Debug mode: {'ON' if DEBUG_MODE else 'OFF'}\n")
    
    current_frame = None
    
    while True:
        try:
            data, addr = sock.recvfrom(BUFFER_SIZE)
            
            line_seq, packet_seq, payload = extract_sequence_numbers(data)
            if line_seq is None:
                continue
            
            # Process the packet
            current_frame, frame_completed = process_packet(
                line_seq, packet_seq, payload, current_frame
            )
            
        except KeyboardInterrupt:
            print("\n[STOP] Interrupted by user")
            if current_frame:
                current_frame.finalize(force=True)
            print(f"\n[STATS] Total UDP payload bytes processed: {total_payload_bytes:,} bytes")
            print(f"[STATS] Total packets received: {packet_loss_stats['total_packets']:,}")
            print(f"[STATS] Packets filled with zeros: {packet_loss_stats['filled_with_zeros']}")
            print(f"[STATS] Out of order packets: {packet_loss_stats['out_of_order']}")
            print(f"[STATS] Estimated lost packets: {packet_loss_stats['lost_packets']}")
            break

# ----------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='UDP Frame Receiver with optimized threading and buffering')
    parser.add_argument("--port", type=int, default=UDP_PORT)
    parser.add_argument("--raw-dir", default=RAW_DIR)
    parser.add_argument("--no-checksum", action="store_true", help="Use raw sockets (root required)")
    parser.add_argument("--wait-time", type=float, default=PACKET_WAIT_TIME, help="Wait time for late packets (seconds)")
    parser.add_argument("--frame-timeout", type=float, default=FRAME_TIMEOUT, help="Frame timeout (seconds)")
    parser.add_argument("--batch-size", type=int, default=LINE_BATCH_SIZE, help="Number of lines to batch before writing")
    parser.add_argument("--debug", action="store_true", help="Enable debug output (prints line/packet numbers)")
    parser.add_argument("--skip-buffer-check", action="store_true", help="Skip UDP buffer limit checks")
    parser.add_argument("--pcap", type=str, help="Read packets from pcap file instead of live capture")
    args = parser.parse_args()

    UDP_PORT = args.port
    RAW_DIR = args.raw_dir
    PACKET_WAIT_TIME = args.wait_time
    FRAME_TIMEOUT = args.frame_timeout
    LINE_BATCH_SIZE = args.batch_size
    DEBUG_MODE = args.debug
    
    os.makedirs(RAW_DIR, exist_ok=True)

    # PCAP mode - read from file
    if args.pcap:
        pcap_reader(args.pcap)
    else:
        # Live capture mode
        # Check UDP buffer limits before starting (unless skipped)
        if not args.skip_buffer_check:
            check_udp_buffer_limits()

        try:
            if args.no_checksum:
                udp_receiver_raw()
            else:
                udp_receiver_normal()
        finally:
            print(f"[INFO] Raw frames saved in: {RAW_DIR}/")

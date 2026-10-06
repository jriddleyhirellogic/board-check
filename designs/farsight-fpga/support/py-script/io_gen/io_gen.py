import argparse
import pandas as pd
from datetime import datetime
from collections import OrderedDict


class ConstrGenerator:
    def __init__(self, in_file, out_file, dev):
        self.in_file = in_file
        self.out_file = out_file
        self.dev = dev
        self.author = "Saba Janamian"
        self.pin_group_col = "group_name"
        self.port_name_col = "fpga_port_name"
        self.pkg_pin_col = "pin_name"
        self.io_std_col = "io_std"
        self.bank_col = "bank"
        self.direction_col = "direction_from_fpga"
        self.fpga_parameters_col = "fpga_parameters"

        self.columns=[
            self.pin_group_col,
            self.port_name_col,
            self.pkg_pin_col,
            "mnemonic",
            "xcvr_number",
            self.bank_col,
            self.io_std_col,
            self.direction_col,
            "Clock_Conditioning",
            "pin_type",
            "fpga_res_pull",
            "comment",
            "vendor_interface_name",
            self.fpga_parameters_col
        ]

        self.default_sec = "MISC"
        self.SKIP_TOKEN = ["TBD", "NA", "NC", "NoPin"]
        self.sections = []
       
    def read_csv(self):
        """
        Reads specified columns from a CSV file and returns a DataFrame.
        """
        try:
            df = pd.read_csv(self.in_file, usecols=self.columns)
            return df
        except Exception as e:
            print(f"An error occurred: {e}")
            return None


    def create_pin_io(self, df):
        """
        Iterates over DataFrame rows and prints pin configuration dictionaries.
        """
        try:
            self.sections = df[self.pin_group_col].unique().tolist()
        except Exception as e:
            print(f"An error occurred while extracting unique group names: {e}")

        self.pinout_dict = OrderedDict((key, []) for key in self.sections) 

        for _, row in df.iterrows():
            if row[self.port_name_col] in self.SKIP_TOKEN:
                continue
            

            dict_cmd  = f"dict set pins "
            fpga_port = str(row[self.port_name_col]).strip()
            pin_dict2 = f"pin_name \"{row[self.pkg_pin_col]}\" "
            
            if not pd.isna(row[self.io_std_col]):
                io_std = row[self.io_std_col]
                pin_dict2 += f"io_std \"{io_std}\" fixed \"true\" "
                
            if row[self.direction_col] == "I":
                pin_dict2 += f"DIRECTION \"INPUT\""
            elif row[self.direction_col] == "O":
                pin_dict2 += f"DIRECTION \"OUTPUT\""
            elif row[self.direction_col] == "IO":
                pin_dict2 += f"DIRECTION \"INOUT\""

            pin_dict = f"{dict_cmd}" + "{" + f"{fpga_port}" + "} "
            pin_dict += "{" + f"{str(pin_dict2).strip()}" + "}"

            sec = self.get_section(row[self.pin_group_col])
            self.pinout_dict[sec].append(pin_dict)
        
    def write_to_file(self):
        with open(self.out_file, "w") as f:
            msg  =  "# Description   : Constraint pinout map\n"
            msg += f"# Target Device : {self.dev}\n"
            msg += f"# Origin Date   : {self.get_date()}\n"
            msg += f"# Originator    : {self.author}\n"
            msg += "#"
            header = f"# {'-' * 78}\n{msg}\n# {'-' * 78}\n"
            f.write(f"{header}\n")

            for sec, constrs in self.pinout_dict.items():
                header = f"\n# {'-' * 78}\n# {sec}\n# {'-' * 78}\n"
                f.write(f"{header}")
                max_len = max(len(constr.split("{pin_name")[0]) for constr in constrs)
                for constr in constrs:
                    parts = constr.split("{pin_name")
                    aligned_constr = f"{parts[0].ljust(max_len)}" + "{" + f"{self.pkg_pin_col}{parts[1]}"
                    f.write(f"{aligned_constr}\n")

    def get_section(self, val):
        for sec in self.sections:
            if sec in val:
                return sec
        return self.default_sec

    @staticmethod
    def get_date():
        now = datetime.now()
        # Format the date and time as MM-DD-YYYY HH:MM:SS
        formatted_now = now.strftime('%m-%d-%Y %H:%M:%S')
        return formatted_now

def main():
    parser = argparse.ArgumentParser(description="Read specific columns from a CSV file.")
    
    parser.add_argument("--infile", "-i", type=str, required=True, help="Path to the input file")
    parser.add_argument("--outfile", "-o", type=str, required=True, help="Path to the output file")
    parser.add_argument("--dev", "-d", type=str, required=True, help="Device information")
    args = parser.parse_args()

    if not args.infile or not args.outfile or not args.dev:
        parser.print_help()
        exit(1)

    builder = ConstrGenerator(args.infile, args.outfile, args.dev)
    df = builder.read_csv()

    if df is not None:
        print("DataFrame loaded successfully.")
        builder.create_pin_io(df)
        builder.write_to_file()
        print(f"File written successfully to {args.outfile}")


if __name__ == "__main__":
    main()

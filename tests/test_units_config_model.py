import pytest

from boardcheck.config import Config
from boardcheck.model import Design, split_part_suffix
from boardcheck.units import format_value, parse_percent, parse_value
from helpers import make_export


@pytest.mark.parametrize("text,unit,expected", [
    ("47nF", "F", 47e-9),
    ("0.1uF", "F", 0.1e-6),
    ("3.3uF", "F", 3.3e-6),
    ("1000pF", "F", 1e-9),
    ("6.3V", "V", 6.3),
    ("2000V", "V", 2000.0),
    ("100mW", "W", 0.1),
    ("0.5W", "W", 0.5),
    ("4K7", "Ω", 4700.0),
    ("49R9", "Ω", 49.9),
    ("0R001", "Ω", 0.001),
    ("R005", "Ω", 0.005),
    ("10K", "Ω", 10000.0),
    ("1M", "Ω", 1e6),
    ("100R", "Ω", 100.0),
    ("0R", "Ω", 0.0),
])
def test_parse_value(text, unit, expected):
    assert parse_value(text, unit) == pytest.approx(expected)


def test_parse_value_rejects_wrong_unit_and_junk():
    assert parse_value("10V", "F") is None
    assert parse_value("", "F") is None
    assert parse_value(None) is None
    assert parse_value("N/A") is None


def test_parse_percent():
    assert parse_percent("1%") == 1.0
    assert parse_percent("0.1%") == 0.1
    assert parse_percent("N/A") is None


def test_format_value():
    assert format_value(47e-9, "F") == "47nF"
    assert format_value(60400, "Ω") == "60.4kΩ"


@pytest.mark.parametrize("net,volts", [
    ("3V3_ASIC", 3.3),
    ("0V6_VTT_16GB", 0.6),
    ("28V0_EPS", 28.0),
    ("1V0A_FPGA", 1.0),
    ("1V25A_FPGA", 1.25),
    ("28V0_EPS_FUSED_15V0_LVDT", 28.0),
    ("N5V0_BIAS", -5.0),
    ("GND", 0.0),
    ("CHAS", 0.0),
    ("3V3_MISC_EN", None),
    ("1V0_FPGA_TLM_ADC", None),
    ("1V2_8GB_ PGOOD", None),
    ("DDR4_16GB_A0", None),
])
def test_net_voltage(net, volts):
    assert Config().net_voltage(net) == volts


def test_sense_nodes_have_voltage_but_are_not_rails():
    c = Config()
    assert c.net_voltage("1V0_FPGA_RSENSE_P") == 1.0
    assert not c.is_rail("1V0_FPGA_RSENSE_P")
    assert c.is_rail("1V0_FPGA")
    assert not c.is_rail("GND")


def test_explicit_voltage_override():
    c = Config({"nets": {"voltages": {"VBAT": 7.4}}})
    assert c.net_voltage("VBAT") == 7.4


def test_kind_by_designator_prefix():
    c = Config()
    d = Design(make_export([("TP1", "TP", []), ("C10", "X", []), ("U3", "Y", []), ("FID2", "F", [])]))
    kinds = {k: c.kind(v) for k, v in d.components.items()}
    assert kinds == {"TP1": "testpoint", "C10": "capacitor", "U3": "ic", "FID2": "mechanical"}


def test_multipart_components_merge_across_sheets():
    export = make_export([
        {"designator": "U5", "partNumber": "DDR", "sheet": "A.SchDoc",
         "parts": [("U5A", [("A1", "DQ0", "D0")])]},
        {"designator": "U5", "partNumber": "DDR", "sheet": "B.SchDoc",
         "parts": [("U5B", [("B1", "VDD", "1V2"), ("B2", "VSS", "GND")])]},
    ])
    d = Design(export)
    u5 = d.components["U5"]
    assert u5.parts == ["U5A", "U5B"]
    assert len(u5.pins) == 3
    assert u5.sheets == ["A.SchDoc", "B.SchDoc"]
    assert [p.ref for p in d.nets["GND"].pins] == ["U5.B2"]


def test_split_part_suffix():
    assert split_part_suffix("U1C") == ("U1", "C")
    assert split_part_suffix("R5") == ("R5", "")
    assert split_part_suffix("FID") == ("FID", "")


def test_title_block_names_the_schematic():
    from helpers import make_export
    raw = make_export([])
    assert Design(raw).schematic_id == ""
    raw["project"]["parameters"] = {"SCH_DWG_Number": "CM-03543", "SCH_Rev": "2", "ASM_Rev": "2"}
    assert Design(raw).schematic_id == "CM-03543 rev 2"
    raw["project"]["parameters"] = [{"name": "SCH_DWG_Number", "value": "CM-1"}]
    assert Design(raw).schematic_id == "CM-1"

#!/usr/bin/env python3
"""
Runtime-triggered Manta capture helper for the existing v3 bitstream.

Examples:
  ./manta_capture_v3.py --trigger pcm EQ 0x170c --out capture_pcm_170c.vcd --csv capture_pcm_170c.csv
  ./manta_capture_v3.py --trigger reset_released RISING --out capture_reset.vcd --csv capture_reset.csv
  ./manta_capture_v3.py --trigger pcm EQ 0x170c --trigger trap_m RISING --out capture_or.vcd

Important: multiple --trigger entries are ORed by Manta hardware, not ANDed.
"""
import argparse
import tempfile
import time

try:
    from manta import Manta
except ImportError:
    from manta.manta import Manta

from manta.logic_analyzer.capture import LogicAnalyzerCapture
from manta.logic_analyzer.fsm import TriggerModes

OPS_WITH_ARG = {"GT", "LT", "GEQ", "LEQ", "EQ", "NEQ"}
OPS_NO_ARG = {"DISABLE", "RISING", "FALLING", "CHANGING"}


def parse_int(s: str) -> int:
    return int(s, 0)


def normalize_trigger(tokens):
    if len(tokens) not in (2, 3):
        raise SystemExit(f"Bad trigger {tokens!r}: use PROBE OP [ARG]")
    probe = tokens[0]
    op = tokens[1].upper()
    if op in OPS_NO_ARG:
        if len(tokens) != 2:
            raise SystemExit(f"Bad trigger {tokens!r}: {op} takes no argument")
        return [probe, op]
    if op in OPS_WITH_ARG:
        if len(tokens) != 3:
            raise SystemExit(f"Bad trigger {tokens!r}: {op} needs an argument")
        return [probe, op, str(parse_int(tokens[2]))]
    raise SystemExit(f"Bad trigger op {op!r}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="manta_cvw_smoke_cpuclk_v3.yaml")
    ap.add_argument("--port", default=None, help="override uart.port from the YAML config")
    ap.add_argument("--baudrate", type=parse_int, default=None, help="override uart.baudrate from the YAML config")
    ap.add_argument("--core", default="cpu_la_v3")
    ap.add_argument("--mode", choices=["single_shot", "incremental", "immediate"], default="single_shot")
    ap.add_argument("--loc", type=parse_int, default=256, help="pre-trigger samples for single_shot")
    ap.add_argument("--trigger", nargs="+", action="append", required=True,
                    help="PROBE OP [ARG], e.g. --trigger pcm EQ 0x170c")
    ap.add_argument("--out", required=True, help="output .vcd")
    ap.add_argument("--csv", default=None, help="optional output .csv")
    ap.add_argument("--retries", type=int, default=3, help="Manta UART retries for register/memory operations")
    ap.add_argument("--retry-delay", type=float, default=0.25, help="delay between Manta UART retries")
    args = ap.parse_args()

    triggers = [normalize_trigger(t) for t in args.trigger]
    mode = TriggerModes[args.mode.upper()]

    config_path = args.config
    if args.port is not None or args.baudrate is not None:
        try:
            import yaml
        except ImportError as e:
            raise SystemExit("PyYAML is required when using --port or --baudrate") from e

        with open(args.config, encoding="utf-8") as f:
            config = yaml.safe_load(f)
        config.setdefault("uart", {})
        if args.port is not None:
            config["uart"]["port"] = args.port
        if args.baudrate is not None:
            config["uart"]["baudrate"] = args.baudrate

        tmp = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False)
        with tmp:
            yaml.safe_dump(config, tmp, sort_keys=False)
        config_path = tmp.name
        print("using config override:", config_path)

    def manta_call(label, fn):
        last_exc = None
        for attempt in range(1, args.retries + 1):
            try:
                return fn()
            except ValueError as e:
                last_exc = e
                if "Only got" not in str(e) or attempt == args.retries:
                    break
                print(f"{label}: Manta UART returned no/short response, retry {attempt}/{args.retries}")
                time.sleep(args.retry_delay)
        port = args.port if args.port is not None else "YAML uart.port"
        baud = args.baudrate if args.baudrate is not None else "YAML uart.baudrate"
        raise SystemExit(
            f"{label}: Manta UART transaction failed on port {port} at baud {baud}: {last_exc}\n"
            "This is a link/core-response failure, not a trigger failure. Check the selected ttyUSB port, "
            "Manta core regeneration, CPUCLK, debug UART wiring, and whether another program has the port open."
        ) from last_exc

    m = Manta.from_config(config_path)
    la = getattr(m.cores, args.core)
    la.define_submodules()

    probe_names = {p.name for p in la._probes}
    for t in triggers:
        if t[0] not in probe_names:
            raise SystemExit(f"Unknown probe {t[0]!r}. Known probes include: {', '.join(sorted(probe_names))}")

    print("stop_capture")
    manta_call("stop_capture", la._fsm.stop_capture)

    print("set trigger block:", triggers)
    manta_call("set_triggers", lambda: la._trig_blk.set_triggers(triggers))

    print("set trigger mode:", mode.name, int(mode))
    manta_call("write trigger_mode", lambda: la._fsm.write_register("trigger_mode", mode))

    trig_loc = args.loc if mode == TriggerModes.SINGLE_SHOT else la._sample_depth // 2
    print("set trigger_location:", trig_loc)
    manta_call("write trigger_location", lambda: la._fsm.write_register("trigger_location", trig_loc))

    # Readback sanity: this catches the v1.1.0 single_shot config bug and wrong runtime programming.
    rb_mode = manta_call("read trigger_mode", lambda: la._fsm.read_register("trigger_mode"))
    rb_loc = manta_call("read trigger_location", lambda: la._fsm.read_register("trigger_location"))
    print("readback trigger_mode    =", rb_mode)
    print("readback trigger_location=", rb_loc)

    for t in triggers:
        op_rb = manta_call(f"read {t[0]}_op", lambda t=t: la._trig_blk.registers.get_probe(t[0] + "_op"))
        arg_rb = manta_call(f"read {t[0]}_arg", lambda t=t: la._trig_blk.registers.get_probe(t[0] + "_arg"))
        print(f"readback {t[0]}_op={op_rb} {t[0]}_arg={arg_rb}")

    print("start_capture")
    manta_call("start_capture", la._fsm.start_capture)
    print("wait_for_capture")
    manta_call("wait_for_capture", la._fsm.wait_for_capture)

    print("read sample memory")
    raw = manta_call("read sample memory", lambda: la._sample_mem.read(list(range(la._sample_depth))))
    rp = manta_call("read read_pointer", lambda: la._fsm.read_register("read_pointer"))
    data = raw[rp:] + raw[:rp]

    cap = LogicAnalyzerCapture(la._probes, trig_loc, mode, data, m.interface)
    cap.export_vcd(args.out)
    print("wrote", args.out)
    if args.csv:
        cap.export_csv(args.csv)
        print("wrote", args.csv)


if __name__ == "__main__":
    main()

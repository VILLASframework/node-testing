# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

import matplotlib.pyplot as plt
import pandas as pd
import glob
import re
import os
import json
from pprint import pprint
from functools import cached_property
from itertools import groupby
from datetime import datetime
from pathlib import PosixPath
from dataclasses import dataclass


results_dir = PosixPath("./results")

regex = re.compile(r"")


@dataclass
class ResultFile:
    filename: PosixPath
    test: str
    date: datetime
    rate: int
    values: int

    @classmethod
    def from_path(cls, path: PosixPath) -> "ResultFile":
        pattern = r"test-rtt_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})_([_a-z]+?)_values(\d+)_rate(\d+)"

        # Search for the pattern in the filename
        match = re.search(pattern, path.as_posix())

        if match:

            date_str = match.group(1)
            time_str = match.group(2)
            test = match.group(3)
            values = match.group(4)
            rate = match.group(5)

            datetime_str = f"{date_str} {time_str.replace('-', ':')}"
            date_time = datetime.strptime(datetime_str, "%Y-%m-%d %H:%M:%S")

            return cls(path, test, date_time, int(rate), int(values))
        else:
            raise ValueError("Filename does not match the expected format")

    @property
    def title(self):
        if self.test == "webrtc":
            return "WebRTC (UDP)"
        elif self.test == "webrtc_relayed_udp":
            return "WebRTC (UDP, relayed)"
        elif self.test == "webrtc_relayed_tcp":
            return "WebRTC (TCP, relayed)"
        elif self.test == "webrtc_tcp":
            return "WebRTC (TCP)"
        elif self.test == "sampled_values":
            return "Sampled Values"
        elif self.test == "websocket":
            return "WebSockets"
        elif self.test == "websocket_relayed":
            return "WebSockets (relayed)"
        elif self.test == "mqtt":
            return "MQTT"
        elif self.test == "loopback":
            return "Loopback"
        elif self.test == "udp":
            return "UDP"
        else:
            return self.test

    @cached_property
    def data(self):
        return pd.read_csv(
            self.filename,
            names=["seconds", "nanoseconds", "offset", "sequence"],
            comment="#",
        )

    @cached_property
    def metadata(self):
        with open(self.filename, "rb") as f:
            try:  # catch OSError in case of a one line file
                f.seek(-2, os.SEEK_END)
                while f.read(1) != b"\n":
                    f.seek(-2, os.SEEK_CUR)
            except OSError:
                f.seek(0)

            last_line = f.readline().decode()

        if last_line.startswith("# "):
            metadata_json = last_line.removeprefix("# ")

            return json.loads(metadata_json)

    def __getattr__(self, name: str):
        return self.data[name]


def find_results(pattern: PosixPath) -> list[ResultFile]:
    return [
        ResultFile.from_path(PosixPath(path)) for path in glob.glob(pattern.as_posix())
    ]


def plot_boxplot(results, fn):
    fig = plt.figure(figsize=(10, 6))

    files = results[0]  # Use newest

    data = pd.DataFrame(
        {file.rate: file.offset * 1e3 for file in sorted(files, key=lambda f: f.rate)}
    )

    data.boxplot(showmeans=False, showfliers=False)

    plt.xlabel("Rate [samples/s]", fontsize=18)
    plt.ylabel("RTT [ms]", fontsize=18)
    plt.grid(True)
    plt.xticks(rotation=-45, fontsize=14)
    plt.yticks(fontsize=14)
    plt.tight_layout()

    fig.savefig(fn, format="svg")


def plot_medians_for_rates(results, fn):
    fig, ax1 = plt.subplots(figsize=(10, 6))

    for test, files in results.items():
        files = files[0]  # Use newest

        files = sorted(files, key=lambda f: f.rate)

        x = [f"{file.rate}" for file in files]
        y = [1e3 * file.offset.median() for file in files]

        ax1.plot(x, y, marker="o", linestyle="-", label=files[0].title)

    plt.xlabel("Rate [samples/s]", fontsize=20)
    plt.ylabel("RTT [ms]", fontsize=20)
    plt.legend(fontsize=13, ncol=2, fancybox=True, loc="lower left", bbox_to_anchor=(0, 0.06))
    plt.grid(True)
    plt.xticks(rotation=-45, fontsize=16)
    plt.yticks(fontsize=16)
    plt.tight_layout()

    fig.savefig(fn, format="svg")


def plot_medians_for_values(results, fn):
    fig = plt.figure(figsize=(10, 6))

    for test, files in results.items():
        files = files[0]  # Use newest

        files = sorted(files, key=lambda f: f.values)

        x = [f"{file.values}" for file in files]
        y = [1e3 * file.offset.median() for file in files]

        plt.plot(x, y, marker="o", linestyle="-", label=files[0].title)

    plt.xlabel("Values per sample", fontsize=20)
    plt.ylabel("RTT [ms]", fontsize=20)
    plt.legend(fontsize=13, ncol=2, fancybox=True, loc="lower left", bbox_to_anchor=(0, 0.06))
    plt.grid(True)
    plt.xticks(rotation=-45, fontsize=16)
    plt.yticks(fontsize=16)
    plt.tight_layout()

    fig.savefig(fn, format="svg")


def group_results(results):
    grouped = {}

    # Group by test
    by_test = sorted(results, key=lambda f: f.test)
    by_test = groupby(by_test, key=lambda f: f.test)

    for test, results in by_test:
        # Group by date
        by_date = sorted(results, key=lambda f: f.date, reverse=True)
        by_date = groupby(by_date, key=lambda f: f.date)

        for date, results in by_date:
            files = [result for result in results]

            mode = "rates" if len({file.rate for file in files}) > 1 else "values"

            m = grouped.setdefault(mode, {})
            t = m.setdefault(test, [])
            t.append(files)

    return grouped


def calc_stats(results):
    stats = {}

    for test, files in results.items():
        files = files[0]  # Use newest

        if test == "loopback":
            continue

        all = pd.concat([file.offset for file in files])

        print()
        print(test)
        print(all.describe())
        print(f"median        {all.median()}")

        pprint(all)

        break


def main():
    pattern = results_dir / "*"
    results = find_results(pattern)
    results = group_results(results)

    for mode, tests in results.items():
        print(f"For mode: {mode}")

        for test, files in tests.items():
            files = files[0]  # Use newest
            print(f" using {len(files)} datasets from {files[0].date} for {files[0].test} with {files[0].values} values at {files[0].rate} smps/s")

    # data = pd.concat([f.offset.rename(f.rate) for f in results], axis=1)

    os.makedirs("plots", exist_ok=True)

    plot_boxplot(results.get("rates").get("webrtc"), f"plots/boxplot_webrtc.svg")
    plot_medians_for_rates(results.get("rates"), "plots/plot_medians_by_rate.svg")
    plot_medians_for_values(results.get("values"), "plots/plot_medians_by_values.svg")

    calc_stats(results.get("rates", {}))


if __name__ == "__main__":
    main()

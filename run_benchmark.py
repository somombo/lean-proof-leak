import math
from pathlib import Path
import re
import statistics
import subprocess

REPOSITORY_ROOT = Path(__file__).resolve().parent
REPRO_EXECUTABLE = REPOSITORY_ROOT / ".lake" / "build" / "bin" / "repro"
SIZES = [1000, 2000, 4000, 8000]
OUTER_REPETITIONS = 7
INNER_REPETITIONS = 7


def build_reproducer():
    subprocess.run(
        ["lake", "build", "-R"],
        cwd=REPOSITORY_ROOT,
        check=True,
    )


def measure_size(size):
    runs_with = []
    runs_without = []

    for _ in range(OUTER_REPETITIONS):
        result = subprocess.run(
            [REPRO_EXECUTABLE, str(size), str(INNER_REPETITIONS)],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )

        match_with = re.search(
            r"with clear_value:\s+(\d+) ns", result.stdout
        )
        match_without = re.search(
            r"without clear_value:\s+(\d+) ns", result.stdout
        )
        if match_with is None or match_without is None:
            raise RuntimeError(
                f"failed to parse benchmark output for size {size}:\n{result.stdout}"
            )

        runs_with.append(int(match_with.group(1)))
        runs_without.append(int(match_without.group(1)))

    if (
        len(runs_with) != OUTER_REPETITIONS
        or len(runs_without) != OUTER_REPETITIONS
    ):
        raise RuntimeError(f"incomplete benchmark data for size {size}")

    return statistics.median(runs_with), statistics.median(runs_without)


def main():
    build_reproducer()

    medians_with = []
    medians_without = []
    for size in SIZES:
        median_with, median_without = measure_size(size)
        medians_with.append(median_with)
        medians_without.append(median_without)

    print("--- Medians ---")
    for size, median_with, median_without in zip(
        SIZES, medians_with, medians_without, strict=True
    ):
        print(f"Size {size}:")
        print(f"  With: {median_with} ns")
        print(f"  Without: {median_without} ns")
        print(f"  Slowdown: {median_without / median_with:.1f}x")

    log_sizes = [math.log(size) for size in SIZES]
    log_with = [math.log(duration) for duration in medians_with]
    log_without = [math.log(duration) for duration in medians_without]

    fit_with, _ = statistics.linear_regression(log_sizes, log_with)
    fit_without, _ = statistics.linear_regression(log_sizes, log_without)

    print("--- Exponents ---")
    print(f"Exponent with clear_value: {fit_with:.3f}")
    print(f"Exponent without clear_value: {fit_without:.3f}")


if __name__ == "__main__":
    main()

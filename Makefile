# Benchmarks
#
# Usage:
#   make benchmark
#   make benchmark BENCHMARK_ARGS='--filter MachOFile.objc.classInfo'
#   make benchmark-baseline-update BASELINE=main

BENCHMARK_DIR := Benchmarks
BENCHMARK_ENV ?= BENCHMARK_DISABLE_JEMALLOC=1
BENCHMARK_ARGS ?=
BASELINE ?= main

.PHONY: benchmark-build
benchmark-build:
	cd $(BENCHMARK_DIR) && $(BENCHMARK_ENV) swift build

.PHONY: benchmark-list
benchmark-list:
	cd $(BENCHMARK_DIR) && $(BENCHMARK_ENV) swift package benchmark list

.PHONY: benchmark
benchmark:
	cd $(BENCHMARK_DIR) && $(BENCHMARK_ENV) swift package benchmark $(BENCHMARK_ARGS)

.PHONY: benchmark-baseline-update
benchmark-baseline-update:
	cd $(BENCHMARK_DIR) && $(BENCHMARK_ENV) swift package --allow-writing-to-package-directory benchmark baseline update $(BASELINE) $(BENCHMARK_ARGS)

.PHONY: benchmark-baseline-compare
benchmark-baseline-compare:
	cd $(BENCHMARK_DIR) && $(BENCHMARK_ENV) swift package benchmark baseline compare $(BASELINE) $(BENCHMARK_ARGS)

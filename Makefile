.PHONY: help up down status logs analyze-17 analyze-18 optimize-17 optimize-18 reset-17 reset-18 run-unoptimized-17 run-optimized-17 run-unoptimized-18 run-optimized-18

# Default target
help:
	@echo "PostgreSQL Performance Tuning Lab - Control Shortcuts"
	@echo "======================================================"
	@echo "Lab Lifecycle Commands:"
	@echo "  make up                          Start PG17 and PG18 containers"
	@echo "  make down                        Stop containers and delete volumes"
	@echo "  make status                      Show running container status"
	@echo "  make logs                        Tail container startup logs"
	@echo ""
	@echo "Benchmarking (runs pgbench for 20 seconds):"
	@echo "  make run-unoptimized-17          Run unoptimized workload on PG 17"
	@echo "  make run-optimized-17            Run optimized workload on PG 17"
	@echo "  make run-unoptimized-18          Run unoptimized workload on PG 18"
	@echo "  make run-optimized-18            Run optimized workload on PG 18"
	@echo ""
	@echo "Diagnostics & Analysis:"
	@echo "  make analyze-17                  Query pg_stat_statements on PG 17"
	@echo "  make analyze-18                  Query pg_stat_statements on PG 18"
	@echo ""
	@echo "Tuning & Housekeeping:"
	@echo "  make optimize-17                 Apply indexes & run ANALYZE on PG 17"
	@echo "  make optimize-18                 Apply indexes & run ANALYZE on PG 18"
	@echo "  make reset-17                    Reset pg_stat_statements on PG 17"
	@echo "  make reset-18                    Reset pg_stat_statements on PG 18"
	@echo "======================================================"

up:
	docker compose up -d

down:
	docker compose down -v

status:
	docker compose ps

logs:
	docker compose logs -f

run-unoptimized-17:
	./scripts/run_benchmark.sh 17 unoptimized 20

run-optimized-17:
	./scripts/run_benchmark.sh 17 optimized 20

run-unoptimized-18:
	./scripts/run_benchmark.sh 18 unoptimized 20

run-optimized-18:
	./scripts/run_benchmark.sh 18 optimized 20

analyze-17:
	docker exec -i tuning_lab_pg17 psql -U postgres -d tuning_lab < scripts/analyze_queries.sql

analyze-18:
	docker exec -i tuning_lab_pg18 psql -U postgres -d tuning_lab < scripts/analyze_queries.sql

optimize-17:
	docker exec -i tuning_lab_pg17 psql -U postgres -d tuning_lab < scripts/apply_tuning.sql

optimize-18:
	docker exec -i tuning_lab_pg18 psql -U postgres -d tuning_lab < scripts/apply_tuning.sql

reset-17:
	docker exec -i tuning_lab_pg17 psql -U postgres -d tuning_lab < scripts/reset_stats.sql

reset-18:
	docker exec -i tuning_lab_pg18 psql -U postgres -d tuning_lab < scripts/reset_stats.sql

# ==============================================================================
# BIG DATA PROJECT PRESENTATION CONTROL PANEL (FINAL FIX)
# ==============================================================================

.PHONY: help up down setup stream-producer stream-flink stream-query batch-job batch-query

# 0. HELP MENU
help:
	@echo "================================================================"
	@echo " PRESENTATION SCENARIO"
	@echo "================================================================"
	@echo " 1. make up           : Start the system"
	@echo " 2. make setup        : Upload data (Create tables)"
	@echo " 3. make stream-prod  : Start Producer (Tweet Stream)"
	@echo " 4. make stream-flink : Start Flink (Analytics)"
	@echo " 5. make monitor      : [NEW] Watch LIVE ALERTs (Console)"
	@echo " 6. make stream-query : Show live data (Hive Table)"
	@echo " 7. make batch-job    : Run batch analytics (Historical Data)"
	@echo " 8. make batch-query  : Show batch results"
	@echo " 9. make down         : Shutdown"
	@echo "================================================================"
	
# 1. SYSTEM
up:
	@echo "[ STARTING ] Bringing containers up..."
	sudo docker compose up -d
	@echo "[ WAIT ] Services are getting ready (20s)..."
	@sleep 20
	@echo "[ OK ] System is ready."

setup:
	@echo "[ PROCESS ] Uploading data to HDFS..."
	-sudo docker exec -it namenode hdfs dfs -mkdir -p /project/raw/
	-sudo docker cp Tweets.csv namenode:/tmp/Tweets.csv
	-sudo docker exec -it namenode hdfs dfs -put -f /tmp/Tweets.csv /project/raw/
	@echo "[ PROCESS ] Registering Hive tables..."
	@sudo docker compose run --rm --entrypoint /bin/bash hive-server -c "\
		rm -rf metastore_db *.log; \
		/opt/hive/bin/schematool -dbType derby -initSchema > /dev/null 2>&1; \
		/opt/hive/bin/hive -hiveconf hive.execution.engine=mr -e \"\
			CREATE EXTERNAL TABLE IF NOT EXISTS tweets_raw_csv (tweet_id STRING, airline_sentiment STRING, airline_sentiment_confidence STRING, negativereason STRING, negativereason_confidence STRING, airline STRING, airline_sentiment_gold STRING, name STRING, negativereason_gold STRING, retweet_count INT, text STRING, tweet_coord STRING, tweet_created STRING, tweet_location STRING, user_timezone STRING) ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde' STORED AS TEXTFILE LOCATION 'hdfs://namenode:9000/project/raw/' TBLPROPERTIES ('skip.header.line.count'='1'); \
			CREATE EXTERNAL TABLE IF NOT EXISTS streamed_tweets (tweet_id STRING, airline_sentiment STRING, airline STRING, retweet_count INT, text STRING, tweet_created STRING) ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe' STORED AS TEXTFILE LOCATION 'hdfs://namenode:9000/project/streamed_tweets_avro/'; \
			CREATE EXTERNAL TABLE IF NOT EXISTS batch_airline_sentiment (airline STRING, total_tweets BIGINT, positive_count BIGINT, negative_count BIGINT, neutral_count BIGINT, negative_ratio DOUBLE) STORED AS PARQUET LOCATION 'hdfs://namenode:9000/project/batch_results_parquet/';\""
	@echo "[ OK ] Setup completed."

# 2. STREAMING
stream-prod:
	@echo "[ CHECK ] Checking venv libraries..."
	@if [ ! -d "venv" ]; then python3 -m venv venv; fi
	@./venv/bin/pip install kafka-python pandas > /dev/null
	@echo "[ INFO ] Starting Producer..."
	@./venv/bin/python3 kafka-scripts/producer.py

stream-flink:
	@echo "[ PREPARATION ] Uploading libraries (Jars)..."
	# 1. Copy JAR files to JobManager and TaskManager
	-sudo docker cp jars flink-jobmanager:/opt/flink/
	-sudo docker cp jars flink-taskmanager:/opt/flink/
	
	# 2. Move JARs into the 'lib' folder (so that Flink can detect them)
	-sudo docker exec -u 0 flink-jobmanager bash -c "mv /opt/flink/jars/* /opt/flink/lib/ 2>/dev/null || true"
	-sudo docker exec -u 0 flink-taskmanager bash -c "mv /opt/flink/jars/* /opt/flink/lib/ 2>/dev/null || true"
	
	@echo "[ RESTART ] Restarting containers (so that libraries are recognized)..."
	# 3. Restart containers (NOW THEY WILL SEE KAFKA)
	sudo docker restart flink-jobmanager flink-taskmanager
	@echo "⏳ System is starting up (wait 15 seconds)..."
	@sleep 15
	
	@echo "[ PYTHON ] Setting up Python environment..."
	# 4. Install Python on both machines (in case it was removed after restart)
	-sudo docker exec -u 0 flink-jobmanager bash -c "apt-get update > /dev/null 2>&1 && apt-get install -y python3 python3-pip > /dev/null 2>&1 && (ln -s /usr/bin/python3 /usr/bin/python 2>/dev/null || true)"
	-sudo docker exec -u 0 flink-taskmanager bash -c "apt-get update > /dev/null 2>&1 && apt-get install -y python3 python3-pip > /dev/null 2>&1 && (ln -s /usr/bin/python3 /usr/bin/python 2>/dev/null || true)"
	
	@echo "[ START ] Submitting Streaming Job..."
	# 5. Copy the script and run it
	sudo docker cp flink-jobs/streaming_job.py flink-jobmanager:/opt/flink/streaming_job.py
	sudo docker exec -u 0 flink-jobmanager chmod 777 /opt/flink/streaming_job.py
	
	sudo docker exec -it flink-jobmanager ./bin/flink run \
		-py /opt/flink/streaming_job.py	

stream-query:
	@echo "[ HACK ] Making hidden Flink files visible..."
	# 1. Read hidden files (.*) -> write into visible_data.json
	sudo docker exec namenode bash -c "hdfs dfs -cat /project/streamed_tweets_avro/.* | hdfs dfs -put -f - /project/streamed_tweets_avro/visible_data.json"
	
	@echo "[ QUERY ] Querying Hive table..."
	# 2. Clean locks (rm -rf) and run the query
	@sudo docker compose run --rm --entrypoint /bin/bash hive-server -c "\
		rm -rf metastore_db *.log; \
		/opt/hive/bin/schematool -dbType derby -initSchema > /dev/null 2>&1; \
		/opt/hive/bin/hive -hiveconf hive.execution.engine=mr -e \"\
			DROP TABLE IF EXISTS streamed_tweets; \
			CREATE EXTERNAL TABLE streamed_tweets (tweet_id STRING, airline_sentiment STRING, airline STRING, retweet_count INT, text STRING, tweet_created STRING) ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe' STORED AS TEXTFILE LOCATION 'hdfs://namenode:9000/project/streamed_tweets_avro/'; \
			SELECT airline, airline_sentiment, text FROM streamed_tweets WHERE tweet_id IS NOT NULL LIMIT 10;\""
# 3. BATCH
batch-job:
	@echo "[ PROCESS ] Spark Batch..."
	@sudo docker cp spark-jobs/spark_batch.py spark-master:/tmp/spark_batch.py
	@sudo docker exec -it spark-master /opt/spark/bin/spark-submit --master spark://spark-master:7077 /tmp/spark_batch.py

batch-query:
	@echo "[ REPORT ] Batch Results (Calculated by Spark)..."
	@sudo docker compose run --rm --entrypoint /bin/bash hive-server -c "\
		rm -rf metastore_db *.log; \
		/opt/hive/bin/schematool -dbType derby -initSchema > /dev/null 2>&1; \
		/opt/hive/bin/hive -hiveconf hive.execution.engine=mr -e \"\
			CREATE EXTERNAL TABLE IF NOT EXISTS batch_airline_sentiment (airline STRING, total_tweets BIGINT, positive_count BIGINT, negative_count BIGINT, neutral_count BIGINT, negative_ratio DOUBLE) STORED AS PARQUET LOCATION 'hdfs://namenode:9000/project/batch_results_parquet/'; \
			SELECT * FROM batch_airline_sentiment;\""

# Newly added part: Live Log Monitoring
monitor:
	@echo "[ WATCH ] Opening Flink Live Logs (Press CTRL+C to exit)..."
	sudo docker logs -f flink-taskmanager

# 4. CLEANUP
down:
	@echo "[ SHUTTING DOWN ]..."
	sudo docker compose down

# Twitter Streaming Analytics Pipeline (Kafka + Flink + Spark + HDFS)

This repository contains a term project that demonstrates a high-performance data processing pipeline for Twitter-style data using **Kafka** (ingestion), **Apache Flink** (real-time streaming), **Apache Spark** (batch analytics), and **HDFS** (distributed storage).  
The whole system can be started easily with **Docker Compose**.
Dataset: Twitter US Airline Sentiment (Kaggle)

---

## Project Overview

The pipeline simulates a modern streaming architecture:

1. **Kafka Producer** reads tweet-like records (CSV/stream) and publishes them to a Kafka topic.
2. **Apache Flink** consumes the Kafka stream and performs real-time processing (streaming analytics).
3. **Apache Spark** runs batch jobs on stored data for offline analytics.
4. **HDFS** is used to store processed results and intermediate data.

This project focuses on:
- Real-time data ingestion and processing
- Stream + batch hybrid analytics
- Reproducible execution using Docker

---

## Tech Stack

- **Apache Kafka** – message broker (topic-based streaming)
- **Apache Flink** – real-time stream processing
- **Apache Spark** – batch processing and analytics
- **HDFS** – distributed file storage
- **Docker & Docker Compose** – deployment and orchestration
- **Python** – streaming and batch job implementations

---

## Repository Structure

twitter_project/
│── docker-compose.yml
│── Makefile
│
├── kafka-scripts/
│ └── producer.py
│
├── flink-jobs/
│ └── streaming_job.py
│
├── spark-jobs/
│ ├── spark_batch.py
│ └── batch_processing.py
│
├── data/
│ └── (optional input files / samples)
│
└── README.md

>  Note: Folders like `hdfs-data/`, large `.jar` files are **not included** in GitHub because they are runtime-generated or too large.  


---

## How to Run

### Requirements
Make sure you have:
- **Docker Desktop** installed and running
- **Docker Compose** available (`docker compose version`)
- Python installed (if running producer locally)

---

# ================================
# RUN THE PROJECT (Makefile-based)
# ================================

# 1) Go to the project folder
cd twitter_project

# 2) Start all containers (Kafka, Flink, Spark, HDFS, Hive, etc.)
make up

# 3) Setup: upload dataset to HDFS + create Hive tables
# (Make sure Tweets.csv exists in the project root before running this!)
make setup

# 4) Start Kafka Producer (simulated tweet stream)
make stream-prod

# 5) Start Flink streaming analysis job
make stream-flink

# 6) (Optional) Monitor Flink logs live (CTRL+C to exit)
make monitor

# 7) Query streaming output from Hive (shows latest processed stream data)
make stream-query

# 8) Run Spark batch job (offline analytics)
make batch-job

# 9) Query batch results from Hive
make batch-query

# 10) Stop the system
make down

## Author

Bengi İlhan

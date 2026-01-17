import os
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings

def main():
    # 1. Flink Ortam Kurulumu
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1)
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, environment_settings=settings)

    # 2. Kaynak: Kafka
    t_env.execute_sql("""
    CREATE TABLE kafka_source (
        tweet_id STRING,
        airline_sentiment STRING,
        airline STRING,
        retweet_count INT,
        text STRING,
        tweet_created STRING
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'tweets_topic',
        'properties.bootstrap.servers' = 'kafka:9093',
        'properties.group.id' = 'flink_group_console_alert',
        'scan.startup.mode' = 'earliest-offset',
        'format' = 'json',
        'json.fail-on-missing-field' = 'false',
        'json.ignore-parse-errors' = 'true'
    )
    """)

    # 3. Hedef 1: HDFS (Tüm veriyi kaydet)
    t_env.execute_sql("""
    CREATE TABLE hdfs_sink (
        tweet_id STRING,
        airline_sentiment STRING,
        airline STRING,
        retweet_count INT,
        text STRING,
        tweet_created STRING
    ) WITH (
        'connector' = 'filesystem',
        'path' = 'hdfs://namenode:9000/project/streamed_tweets_avro/',
        'format' = 'json',
        'sink.rolling-policy.file-size' = '128MB',
        'sink.rolling-policy.rollover-interval' = '1 min',
        'sink.rolling-policy.check-interval' = '1 min'
    )
    """)

    # 4. Hedef 2: Console Alert (Sadece Negatifleri Bas)
    t_env.execute_sql("""
    CREATE TABLE print_sink (
        uyari_mesaji STRING
    ) WITH (
        'connector' = 'print'
    )
    """)

    # 5. StatementSet ile ikisini ayni anda calistir
    statement_set = t_env.create_statement_set()

    # Gorev A: HDFS'e Yaz
    statement_set.add_insert_sql("""
    INSERT INTO hdfs_sink
    SELECT tweet_id, airline_sentiment, airline, retweet_count, text, tweet_created
    FROM kafka_source
    """)

    # Gorev B: Konsola Alert Bas (Sadece Negatifler)
    statement_set.add_insert_sql("""
    INSERT INTO print_sink
    SELECT CONCAT('ALERT [', airline, ']: ', text)
    FROM kafka_source
    WHERE airline_sentiment = 'negative'
    """)

    statement_set.execute()

if __name__ == '__main__':
    main()
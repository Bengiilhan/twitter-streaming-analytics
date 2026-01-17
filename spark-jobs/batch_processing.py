from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, when

spark = SparkSession.builder \
    .appName("TwitterBatch") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .enableHiveSupport() \
    .getOrCreate()

# Veriyi oku
print("Veri okunuyor...")
df = spark.read.option("header", "true").csv("hdfs://namenode:9000/project/raw/Tweets.csv")

# Analiz
print("Analiz yapılıyor...")
results = df.groupBy("airline").agg(
    count("*").alias("total_tweets"),
    count(when(col("airline_sentiment") == "positive", 1)).alias("positive_count"),
    count(when(col("airline_sentiment") == "negative", 1)).alias("negative_count"),
    count(when(col("airline_sentiment") == "neutral", 1)).alias("neutral_count")
).withColumn("negative_ratio", col("negative_count") / col("total_tweets"))

results.show()

# Yazma
print("HDFS'e yazılıyor...")
results.write.mode("overwrite").parquet("hdfs://namenode:9000/project/batch_results_parquet/")

spark.stop()

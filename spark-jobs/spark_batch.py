from pyspark.sql import SparkSession
from pyspark.sql import functions as F

def main():
    # 1. Spark Oturumunu Başlat
    print("Spark Batch Job Baslatiliyor...")
    spark = SparkSession.builder \
        .appName("AirlineSentimentBatchAnalysis") \
        .getOrCreate()

    # 2. HDFS'ten Ham CSV Verisini Oku
    # Not: Hive Metastore kilidiyle uğraşmamak için dosyayı direkt HDFS yolundan okuyoruz.
    input_path = "hdfs://namenode:9000/project/raw/*.csv" # Yüklediğimiz Tweets.csv
    
    print(f"Veri okunuyor: {input_path}")
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(input_path)

    # 3. Analiz ve Aggregation (Toplama) İşlemleri
    # Proje Gereksinimi: Total counts of positive, negative, neutral per airline.
    print("Analiz yapiliyor (Gruplama ve Sayma)...")
    
    result_df = df.groupBy("airline").agg(
        F.count("*").alias("total_tweets"),
        F.sum(F.when(F.col("airline_sentiment") == "positive", 1).otherwise(0)).alias("positive_count"),
        F.sum(F.when(F.col("airline_sentiment") == "negative", 1).otherwise(0)).alias("negative_count"),
        F.sum(F.when(F.col("airline_sentiment") == "neutral", 1).otherwise(0)).alias("neutral_count")
    )

    # 4. Negative Ratio Hesabı
    # Proje Gereksinimi: Calculate "negative ratio" (negative_count / total_tweets)
    print("Oranlar hesaplaniyor...")
    final_df = result_df.withColumn(
        "negative_ratio", 
        F.col("negative_count") / F.col("total_tweets")
    )

    # 5. Sonucu HDFS'e Parquet Olarak Yaz
    output_path = "hdfs://namenode:9000/project/batch_results_parquet/"
    print(f"Sonuc HDFS'e yaziliyor: {output_path}")
    
    final_df.write \
        .mode("overwrite") \
        .parquet(output_path)

    print("Batch Job Tamamlandi! HDFS'i kontrol edebilirsiniz.")
    spark.stop()

if __name__ == "__main__":
    main()

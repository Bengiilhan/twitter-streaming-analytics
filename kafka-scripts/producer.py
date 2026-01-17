import pandas as pd
from kafka import KafkaProducer
import time
import json
import os

# --- AYARLAR ---
KAFKA_TOPIC = "tweets_topic"
KAFKA_SERVER = "kafka:9092"
CSV_FILE_PATH = "Tweets.csv"

def json_serializer(data):
    return json.dumps(data).encode("utf-8")

# Mesaj başarıyla giderse burası çalışır
def on_send_success(record_metadata):
    pass # Sessizce devam et, ekranı kirletme

# Mesaj GİTMEZSE burası çalışır ve hatayı basar
def on_send_error(excp):
    print(f"HATA: Mesaj gönderilemedi! Sebep: {excp}")

def main():
    print(f"Kafka Producer başlatılıyor... Hedef: {KAFKA_SERVER}")
    
    # 1. Producer'ı Başlat (api_version EKLENDİ!)
    try:
        producer = KafkaProducer(
            bootstrap_servers=[KAFKA_SERVER],
            value_serializer=json_serializer,
            api_version=(0, 10, 1), 
            retries=5
        )
        print("Kafka bağlantısı başarılı!")
    except Exception as e:
        print(f"Kafka'ya bağlanılamadı. Hata: {e}")
        return

    if not os.path.exists(CSV_FILE_PATH):
        print(f"HATA: {CSV_FILE_PATH} dosyası bulunamadı!")
        return

    print("CSV dosyası okunuyor...")
    # Sadece gerekli kolonları al
    columns_to_keep = ['tweet_id', 'airline_sentiment', 'airline', 'retweet_count', 'text', 'tweet_created']
    df = pd.read_csv(CSV_FILE_PATH, usecols=columns_to_keep)
    df = df.fillna("")

    print(f"Toplam {len(df)} tweet bulundu. Akış başlıyor... ")

    count = 0
    try:
        for _, row in df.iterrows():
            message = row.to_dict()
            
            # Callback ekledik: Gitti mi gitmedi mi kontrol et
            producer.send(KAFKA_TOPIC, message).add_callback(on_send_success).add_errback(on_send_error)
            
            count += 1
            if count % 100 == 0:
                print(f"-> {count} tweet gönderildi...")
            
            time.sleep(0.1) 

        producer.flush()
        print(f"\nTamamlandı! Toplam {count} tweet başarıyla gönderildi.")

    except KeyboardInterrupt:
        print("\nİşlem durduruldu.")
    except Exception as e:
        print(f"\nBir hata oluştu: {e}")
    finally:
        producer.close()

if __name__ == "__main__":
    main()

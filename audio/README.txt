ARKA PLAN MÜZİĞİ / BACKGROUND MUSIC
====================================

Buraya oyun müziğini koy. Dosya adı ŞUNLARDAN biri olmalı (ilk bulunan çalınır):

    audio/music.ogg      (ÖNERİLEN — sorunsuz döngü için en iyisi)
    audio/music.mp3
    audio/music.wav

Yani bu klasöre (end-of-shift-godot/audio/) müziğini
"music.ogg" adıyla koyman yeterli. Oyun otomatik bulur, döngüde
sakin şekilde çalar ve ana menüdeki "Music ON/OFF" düğmesiyle
açılıp kapanır.

Notlar:
- .ogg formatı önerilir (Godot döngüyü otomatik yapar).
- Ses seviyesi kod içinde kısık ayarlı (arka planda kalsın diye);
  istersen Sfx.gd içinde `_music.volume_db` değerini değiştirebiliriz.
- Dosya yoksa oyun yine sorunsuz çalışır (sadece müzik olmaz).

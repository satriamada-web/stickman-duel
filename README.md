# Stickman Duel

Game fighting 2D berbasis Godot 4 untuk Android.

## Konsep
- Pertarungan stickman 1 vs 1.
- Target multiplayer offline melalui Wi-Fi hotspot / LAN.
- Pemain memilih karakter, senjata, dan skill.
- Tidak membutuhkan internet saat bermain di jaringan lokal.

## Teknologi
- Godot Engine 4
- GDScript
- ENet Multiplayer API (tahap pengembangan berikutnya)

## Fitur prototipe saat ini
- Menu utama dan pemilihan karakter.
- Swordman: 100 HP, kecepatan seimbang, damage 15.
- Axeman: 110 HP, damage 22.
- Spearman: 90 HP, jangkauan serang lebih jauh.
- Arena latihan melawan lawan AI sederhana.
- Timer 90 detik dan sistem menang/kalah.
- Kontrol sentuh dan keyboard.

## Cara membuka proyek

### Opsi A — Menggunakan komputer (disarankan)
1. Unduh dan instal Godot Engine 4 dari https://godotengine.org/download/.
2. Unduh repository ini sebagai ZIP dari tombol **Code → Download ZIP**, lalu ekstrak.
3. Buka Godot, tekan **Import**.
4. Pilih file `project.godot` di folder hasil ekstrak.
5. Tekan **Import & Edit**, lalu **Run Project** (F6/F5).

### Opsi B — Menggunakan Android
1. Buka halaman unduhan resmi Godot: https://godotengine.org/download/android/.
2. Unduh Godot Editor untuk Android yang sesuai dengan perangkat.
3. Unduh repository ini sebagai ZIP dari GitHub, lalu ekstrak menggunakan pengelola file.
4. Buka Godot Editor, pilih **Import**, lalu arahkan ke file `project.godot`.
5. Jalankan proyek dari editor.

Catatan: mengedit dan menjalankan proyek di Android dapat terasa kurang nyaman pada layar kecil. Komputer lebih disarankan untuk proses pengembangan dan ekspor APK.

## Kontrol
- KIRI / KANAN: bergerak (tahan tombol).
- BERHENTI: menghentikan gerakan.
- SERANG: menyerang.
- Keyboard: A/D atau panah kiri/kanan, Space untuk menyerang.

## Status pengembangan
**Tahap 1 — Prototipe dasar dan pemilihan karakter.**

Multiplayer LAN belum diimplementasikan. APK belum dibuat. Langkah berikutnya adalah menjalankan dan memeriksa prototipe di Godot, memperbaiki temuan error, lalu membangun sistem lobby host/join untuk dua perangkat pada jaringan Wi-Fi yang sama.

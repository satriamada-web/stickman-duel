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
- Animasi prosedural berjalan, idle, dan serangan.
- Efek kilat saat terkena serangan dan indikator benturan sederhana.

## Cara membuka dan mengembangkan proyek

### Alur utama — menggunakan HP Android
1. Unduh **Godot Editor untuk Android** dari [halaman resmi Godot](https://godotengine.org/download/android/) atau Google Play Store.
2. Unduh repository ini sebagai ZIP melalui tombol **Code → Download ZIP** di GitHub.
3. Ekstrak ZIP ke folder yang mudah ditemukan, misalnya **Download/Stickman-Duel**.
4. Buka Godot Editor Android dan berikan izin akses file saat diminta.
5. Pilih **Import**, lalu pilih file `project.godot` dari folder proyek.
6. Buka proyek dan tekan tombol **Run Project** untuk menjalankan prototipe.

**Catatan Android:** Godot Editor Android masih eksperimental dan tampilannya belum dioptimalkan untuk layar sentuh. Keyboard dan mouse Bluetooth sangat membantu. Pastikan perangkat memiliki dukungan OpenGL ES 3.0 atau lebih tinggi. Untuk tahap awal, kita memakai renderer Compatibility agar lebih sesuai dengan perangkat Android yang mendukungnya.

### Alternatif — menggunakan komputer
1. Unduh dan instal Godot Engine 4 dari https://godotengine.org/download/.
2. Unduh repository ini sebagai ZIP, lalu ekstrak.
3. Buka Godot, tekan **Import**, dan pilih file `project.godot`.
4. Tekan **Import & Edit**, lalu **Run Project**.

### Catatan ekspor APK
Godot Android Editor versi terbaru mendukung ekspor proyek Android. Namun, proses ekspor dan pemasangan APK akan kita siapkan setelah prototipe berhasil dijalankan dan diuji. Jadi, saat ini belum tersedia APK siap instal.

## Kontrol
- KIRI / KANAN: bergerak (tahan tombol).
- BERHENTI: menghentikan gerakan.
- SERANG: menyerang.
- Keyboard: A/D atau panah kiri/kanan, Space untuk menyerang.

## Status pengembangan
**Tahap 1 — Prototipe dasar dan pemilihan karakter.**

Multiplayer LAN belum diimplementasikan. APK belum dibuat. Langkah berikutnya adalah menjalankan dan memeriksa prototipe di Godot, memperbaiki temuan error, lalu membangun sistem lobby host/join untuk dua perangkat pada jaringan Wi-Fi yang sama.

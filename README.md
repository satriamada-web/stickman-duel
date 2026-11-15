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

## Menjalankan
1. Instal Godot Engine 4.
2. Pilih **Import**.
3. Pilih file `project.godot` dari repository.
4. Tekan **Run Project**.

## Kontrol
- KIRI / KANAN: bergerak (tahan tombol).
- BERHENTI: menghentikan gerakan.
- SERANG: menyerang.
- Keyboard: A/D atau panah kiri/kanan, Space untuk menyerang.

## Status pengembangan
**Tahap 1 — Prototipe dasar dan pemilihan karakter.**

Multiplayer LAN belum diimplementasikan. Selanjutnya: uji prototipe di Godot, lalu bangun sistem lobby host/join untuk dua perangkat pada jaringan Wi-Fi yang sama.

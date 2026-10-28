# ARCHITECTURE.md (9RouterAndroid, gabungan v1.0.0)

## Gambaran
Android memakai bionic, bukan glibc, sehingga biner Node.js resmi
linux-arm64 tidak bisa jalan langsung. Module ini menjalankan Node
lewat loader glibc yang dibundel, dengan library path ke pustaka
glibc yang sama. Tidak ada proot, tidak ada Termux, tidak ada
ketergantungan runtime module lain untuk jalan.

## Komponen
- `glibc.tar.gz` (di dalam zip): pustaka Debian 13 trixie aarch64
  yang dibangun di VM dari paket resmi libc6 2.41, libstdc++6 14.2.0,
  dan libgcc-s1 14.2.0. Isinya loader, libc, libm, libdl, libpthread,
  librt, libanl, libutil, libresolv, libnss_compat, libnss_dns,
  libnss_files, libnss_hesiod, libgcc_s, dan libstdc++.
- `customize.sh`: saat flash, cek aarch64 dan ruang kosong, hentikan
  instance lama, ekstrak glibc, salin helper dan wrapper, pakai ulang
  Node Hermes bila ada atau unduh Node 22 LTS resmi dengan cek
  SHA256, bangun CA bundle Android sebagai NODE_EXTRA_CA_CERTS
  (best effort), buat settings.ini dengan password acak bila belum
  ada, instal 9Router lewat `9router update --no-restart`, lalu
  self-test sekali di port cadangan. Menulis `.install_state=done`
  hanya bila semua langkah sukses.
- `scripts/node-wrapper.sh`: wrapper Node lewat loader glibc,
  mengosongkan LD_PRELOAD, dan punya escape hatch native untuk
  pengujian di Linux glibc saja.
- `scripts/node-compat.cjs`: preload Node yang memperbaiki
  process.execPath, membuat os.networkInterfaces dan os.userInfo
  tidak fatal, mencegah Next.js mengganti nama proses agar pgrep
  bekerja, dan DNS-over-HTTPS di dalam proses ke resolver publik
  bila `doh=auto`, fallback ke resolver standar bila diblokir.
- `scripts/nr-tool.cjs`: helper tanpa npm di HP untuk mengunduh
  rilis 9Router dari registry npm, memeriksa kesehatan endpoint,
  dan membuat API key lewat dashboard.
- `scripts/9router.sh`: kontrol utama yang diinstal ke
  `/data/adb/9router/bin/9router`. Mengelola rilis di
  `releases/<ver>/` dengan symlink `current` dan rilis sebelumnya
  untuk rollback, lock update, health check 60 detik, dan perintah
  lengkap termasuk doctor dan link-hermes.
- `service.sh`: tiap boot, tunggu boot_completed, hormati
  autostart=false, tautkan CLI ke /data/adb/ksu/bin atau
  /data/adb/ap/bin, lalu `9router start --nowait`.
- `action.sh`: tombol Action manager, mulai bila perlu, buka
  dashboard, tampilkan password awal.
- `system/bin/9router`: overlay Magisk ke /system/bin, wrapper ke
  `/data/adb/9router/bin/9router`.
- `uninstall.sh`: hentikan proses, hapus symlink CLI, hapus glibc,
  node, releases, bin, tmp, home, dan log, tetapi pertahankan data
  dan settings.ini.

## Aliran data
Browser HP -> http://127.0.0.1:20128/dashboard dan /v1 -> proses Node
9Router (custom-server.js langsung, bukan TUI) -> provider LLM yang
user hubungkan sendiri di dashboard. Tidak ada data yang dikirim
module ini ke server pihak ketiga mana pun, selain unduhan saat flash
(nodejs.org dan registry npm) dan koneksi provider yang user atur
sendiri di 9Router.

## Keputusan yang sengaja diambil
- Basis skrip gabungan dipakai karena sudah punya manajemen rilis,
  rollback, doctor, self-test, dan password acak, yang tidak ada di
  draf sederhana awal.
- glibc dibangun ulang dari Debian resmi, bukan disalin dari bundle
  module lain, agar asal pustaka jelas dan lisensi LGPL tercatat.
- ID module diubah ke 9routerandroid dan semua variabel internal
  diubah ke ROUTERANDROID_ agar konsisten dengan repo dan branding.
- Uninstall mempertahankan settings.ini, berbeda dari versi percobaan
  yang menghapusnya, agar preferensi dan password awal tidak hilang
  sia-sia saat instal ulang.
- INITIAL_PASSWORD acak dipakai, bukan default upstream, karena
  dashboard loopback pun sebaiknya tidak memakai password yang
  diketahui publik.
- Node tidak dibundel di zip agar zip tetap sekitar 2 MB dan Node
  selalu versi 22 LTS terbaru saat flash. Kekurangannya flash wajib
  internet, dan itu ditulis jelas di README.

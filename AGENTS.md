# AGENTS.md (per proyek 9RouterAndroid)

## Aturan kerja proyek ini
- Bahasa kerja: Indonesia kasual di chat, komentar kode seperlunya saja.
- Shell yang dipakai module adalah POSIX sh (`#!/system/bin/sh`), bukan
  bash. Jangan pakai array, `[[ ]]`, atau fitur bash lain, karena
  lingkungan instalasi Magisk/KernelSU tidak menjamin bash.
- Jangan pernah menyalin skrip module lain mentah-mentah. Pola yang boleh
  dipakai ulang hanya pola umum module Magisk/KernelSU (module.prop,
  customize.sh, service.sh, action.sh, uninstall.sh, META-INF stub).
- Jangan tambahkan redirect DNS level sistem, proxy sistem, atau
  iptables. Module ini hanya menjalankan 9Router. Pengecualian yang
  sudah menjadi bagian desain gabungan v1.0.0: DNS-over-HTTPS hanya
  di dalam proses Node (bisa dimatikan dengan doh=off) dan CA bundle
  dari toko sertifikat Android hanya untuk TLS Node, bukan untuk
  mengubah sistem.
- Jangan commit data user, token, API key, atau password ke repo.
- Setiap perubahan skrip wajib lolos `sh -n` dan cek isi zip sebelum
  push. Klaim sukses hanya setelah verifikasi remote, bukan setelah
  perintah lokal sukses.

## Layout runtime di HP
- `/data/adb/9router/` : root runtime module ini.
- `/data/adb/9router/glibc/lib/` : loader dan pustaka glibc dari zip.
- `/data/adb/9router/node/` : Node.js 22 LTS resmi, linux-arm64.
- `/data/adb/9router/bin/` : wrapper `node` dan kontrol `9router`.
- `/data/adb/9router/releases/` : rilis npm 9Router, `current`
  menunjuk ke rilis aktif, rilis sebelumnya untuk rollback.
- `/data/adb/9router/data/` : data 9Router (DATA_DIR), dipertahankan
  saat uninstall dan update.
- `/data/adb/9router/settings.ini` : `autostart=true` default.
- `/data/adb/9router/.install_state` : bernilai `done` bila instalasi
  flash selesai penuh. service.sh menolak jalan bila bukan `done`.

## Alur rilis
1. Ubah module.prop (version dan versionCode +1).
2. Bangun zip dari isi folder `module/` saja, bukan dari root repo.
3. Push ke GitHub OmmniDevv/9RouterAndroid lewat gh-pat.
4. Buat GitHub Release dengan tag `v<version>` dan lampirkan zip yang
   sama persis dengan yang diuji.
5. Verifikasi dari remote: unduh info rilis dan daftar isi zip, lalu
   laporkan tautan rilisnya.

## Aturan tambahan v1.0.0 (perintah user 2026-10-28)
- Branding: module dibuat oleh OmmniDevv. Tidak ada atribusi asisten
  di commit, pesan commit, README, atau file repo lainnya.
- README wajib lengkap dan dua bahasa: Bahasa Indonesia penuh, lalu
  English penuh, bukan ringkasan terjemahan.
- Setiap update wajib ganti versi: version naik, versionCode +1,
  update.json diperbarui, zip rilis baru, GitHub Release baru.
- Standar matang: jangan rilis setengah matang. Semua skrip lolos
  sh -n atau node --check, zip diperiksa isinya, grep atribusi
  diperiksa, dan hasil remote diverifikasi sebelum laporan.
- Lisensi repo: MIT.
- Banner GitHub ada di root repo sebagai banner.png dan tampil di
  atas README.

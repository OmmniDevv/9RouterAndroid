![9RouterAndroid banner](banner.png)

# 9RouterAndroid

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.4-blue.svg)](https://github.com/OmmniDevv/9RouterAndroid/releases/tag/v1.0.4)
[![Platform: Android aarch64](https://img.shields.io/badge/Platform-Android%20aarch64-orange.svg)](#syarat--requirements)

Module Magisk / KernelSU / APatch untuk menjalankan 9Router di HP Android
yang sudah di-root. Dibuat oleh **OmmniDevv**.

Magisk / KernelSU / APatch module to run 9Router on a rooted Android phone.
Made by **OmmniDevv**.

- [Bahasa Indonesia](#bahasa-indonesia)
- [English](#english)

---

## Bahasa Indonesia

### Tentang

9Router adalah gateway LLM yang kompatibel dengan API OpenAI. Satu endpoint
lokal bisa meneruskan permintaan ke banyak provider, dengan fallback otomatis
bila satu provider gagal atau limit. 9RouterAndroid memasang 9Router sebagai
service di HP, tanpa Termux dan tanpa proot.

Yang didapat setelah instal:

- Dashboard di `http://127.0.0.1:20128/dashboard`
- API OpenAI-compatible di `http://127.0.0.1:20128/v1`
- Perintah root `9router` untuk start, stop, status, update, dan rollback
- Runtime mandiri: glibc yang dibundel di zip module, plus Node.js 22 LTS
  yang dipakai ulang dari HermesAndroid bila sudah ada, atau diunduh resmi
  dari nodejs.org bila belum ada

### Syarat

- HP Android **aarch64** (ARM 64-bit). Arsitektur lain ditolak saat flash.
- Sudah di-root dengan Magisk, KernelSU, atau APatch.
- Koneksi internet saat flash, karena Node.js dan paket 9Router diunduh
  pada saat itu. Setelah terinstal, 9Router jalan lokal dan tidak butuh
  Termux.
- Ruang kosong di `/data` minimal 500 MB saat flash. Pemakaian setelah
  instal sekitar 120 MB bila Node.js dipakai ulang, atau sekitar 300 MB
  pada puncaknya bila Node.js harus diunduh juga.

### Instalasi

1. Unduh `9RouterAndroid-v1.0.4.zip` dari halaman
   [Releases](https://github.com/OmmniDevv/9RouterAndroid/releases).
2. Flash zip itu di Magisk, KernelSU, atau APatch Manager, dalam keadaan
   internet menyala.
3. Tunggu sampai log flash selesai. Module melakukan self-test sekali
   dengan menjalankan 9Router di port cadangan untuk membuktikan runtime
   bekerja di HP itu.
4. Reboot, atau jalankan `su -c '9router start'`.
5. Tekan tombol Action di manager, atau buka
   `http://127.0.0.1:20128/dashboard` di browser HP.
6. Login dengan password awal yang tampil di log flash dan di perintah
   `su -c '9router password'`, lalu **ganti password itu di dashboard
   secepatnya**.

### Cara pakai

#### Dashboard dan API

- Dashboard: `http://127.0.0.1:20128/dashboard`
- API base: `http://127.0.0.1:20128/v1`
- Contoh pemakaian API dari aplikasi yang mendukung OpenAI-compatible:
  base URL `http://127.0.0.1:20128/v1`, API key diambil dari dashboard,
  model dipilih dari daftar model yang tersedia di dashboard.

Tambahkan provider dan buat API key di dashboard seperti biasa. Jangan
membagikan API key 9Router ke orang lain, dan jangan membuka dashboard ke
jaringan lain kecuali kamu paham risikonya.

#### Perintah CLI

Semua perintah dijalankan sebagai root, contoh `su -c '9router status'`.

| Perintah | Fungsi |
| --- | --- |
| `9router status` | Menampilkan status, versi, bind, dan autostart |
| `9router start` | Memulai 9Router |
| `9router stop` | Menghentikan 9Router |
| `9router restart` | Menghentikan lalu memulai ulang |
| `9router log` | Menampilkan log, tambah `-f` untuk mengikuti log |
| `9router url` | Menampilkan URL dashboard dan API |
| `9router password` | Menampilkan password awal dashboard |
| `9router config` | Menampilkan konfigurasi |
| `9router config set KEY VALUE` | Mengubah satu kunci, lalu `9router restart` |
| `9router update` | Memperbarui 9Router dari npm, dengan rollback otomatis bila gagal start |
| `9router update --check` | Mengecek pembaruan tanpa menginstal |
| `9router update --version X` | Memasang versi 9Router tertentu |
| `9router rollback` | Kembali ke rilis 9Router sebelumnya |
| `9router doctor` | Diagnosa runtime, disk, dan kesehatan service |
| `9router selftest` | Boot sekali di port cadangan untuk pengujian |
| `9router version` | Menampilkan versi 9Router dan versi module |
| `9router models` | Menampilkan daftar model |
| `9router models <filter>` | Menampilkan model yang cocok dengan filter |

#### Konfigurasi

File konfigurasi ada di `/data/adb/9router/settings.ini`. Ubah dengan
`9router config set KEY VALUE`, lalu `9router restart`.

| Kunci | Default | Arti |
| --- | --- | --- |
| `port` | `20128` | Port dashboard dan API |
| `host` | `127.0.0.1` | Bind loopback saja. Ubah ke `0.0.0.0` hanya bila kamu sadar dashboard jadi bisa diakses dari jaringan lokal, dan ganti password dulu |
| `autostart` | `true` | Jalan otomatis tiap boot |
| `max_old_space` | `768` | Batas heap V8 dalam MB, disesuaikan untuk HP |
| `initial_password` | acak per perangkat | Password awal dashboard sampai kamu menggantinya di dashboard |
| `doh` | `auto` | DNS-over-HTTPS di dalam proses Node, `off` untuk menonaktifkan |
| `hermes_dir` | `/data/adb/hermes` | Lokasi HermesAndroid bila ada |

#### Menghubungkan HermesAndroid (opsional)

Bila HermesAndroid terinstal dan kamu ingin Hermes memakai 9Router
sebagai provider, jalankan:

```sh
su -c '9router models'
su -c '9router link-hermes --model <provider/model>'
su -c 'hermes.service restart'
```

Perintah `link-hermes` membuat API key bernama `hermes-android` di
9Router, menulis base URL dan key ke konfigurasi Hermes, dan menyimpan
salinan asli konfigurasi Hermes dengan akhiran `.routerandroid.bak`.
Langkah ini opsional dan hanya mengubah konfigurasi Hermes bila kamu
menjalankannya sendiri.

### Update dan penomoran versi

Aturan versi module ini, dan janji untuk setiap rilis berikutnya:

- Setiap pembaruan module **wajib** menaikkan `version` di `module.prop`
  dan menaikkan `versionCode` sebesar 1.
- Versi awal adalah **1.0.0** dengan `versionCode` **100**.
- File zip rilis selalu bernama `9RouterAndroid-v<version>.zip`.
- File `update.json` di branch `main` selalu diperbarui ke versi terbaru,
  sehingga manager yang mendukung updateJson bisa mengecek pembaruan.
- Changelog tiap rilis ada di halaman Releases GitHub.

Untuk memperbarui 9Router di dalam module tanpa memperbarui module itu
sendiri, pakai `su -c '9router update'`. Bila rilis baru gagal start,
module otomatis mengembalikan rilis sebelumnya. Untuk kembali manual,
pakai `su -c '9router rollback'`.

Untuk memperbarui module ke versi berikutnya, flash zip versi baru di
manager seperti instal biasa. Data di `/data/adb/9router/data` dan
`settings.ini` dipertahankan saat update.

### Uninstall

Hapus module dari Magisk, KernelSU, atau APatch Manager seperti biasa.
Proses 9Router dihentikan, runtime yang bisa diunduh ulang dihapus, tetapi
data berikut dipertahankan agar instal ulang bisa lanjut dari kondisi
terakhir:

- `/data/adb/9router/data` (database, kredensial provider, API key)
- `/data/adb/9router/settings.ini`

Bila kamu ingin menghapus total, hapus kedua lokasi itu manual sebagai
root setelah module dihapus.

### Troubleshooting

| Gejala | Kemungkinan penyebab dan solusi |
| --- | --- |
| Flash gagal, arsitektur tidak didukung | HP bukan aarch64. Module ini hanya untuk aarch64 |
| Flash gagal, tidak cukup ruang | Kosongkan `/data` sampai tersedia minimal 500 MB, lalu flash ulang |
| Flash gagal, tidak ada internet | Node.js dan paket 9Router diunduh saat flash. Sambungkan internet lalu flash ulang |
| Self-test gagal saat flash | Lihat `/data/adb/9router/selftest.log` dan `/data/adb/9router/install.log`, lalu jalankan `su -c '9router doctor'` setelah reboot |
| Dashboard tidak bisa dibuka | Pastikan service jalan dengan `su -c '9router status'`, lalu `su -c '9router start'` dan cek `su -c '9router log'` |
| Lupa password | Password awal ada di `su -c '9router password'`. Bila sudah diganti di dashboard, yang berlaku adalah password baru itu |
| Setelah update 9Router gagal start | Module otomatis rollback. Cek dengan `su -c '9router status'` dan `su -c '9router rollback'` bila perlu |
| HP agresif mematikan proses latar | Kecualikan manager root dan proses ini dari optimasi baterai bila perlu |

### Keamanan

- Service hanya bind ke loopback `127.0.0.1` secara default. Jangan ubah
  ke `0.0.0.0` tanpa mengganti password dashboard dulu.
- Password awal dibuat acak per perangkat dan disimpan di
  `/data/adb/9router/settings.ini` dengan mode 600. Tetap ganti di
  dashboard setelah login pertama.
- Module ini tidak mengubah iptables, tidak memasang redirect DNS di
  level sistem, dan tidak memasang proxy sistem. DNS-over-HTTPS hanya
  berjalan di dalam proses Node 9Router, dan bisa dimatikan dengan
  `doh=off`.
- Module ini tidak mengirim data user ke server mana pun selain unduhan
  saat flash (nodejs.org dan registry npm) dan koneksi provider yang
  kamu atur sendiri di dashboard 9Router.

### File di HP

```text
/data/adb/9router/
  bin/9router            skrip kontrol, juga ditautkan ke /data/adb/ksu/bin atau /data/adb/ap/bin
  node/bin/node          wrapper ke loader glibc, node.real adalah biner Node asli
  glibc/lib/             loader dan pustaka glibc
  releases/<ver>/        paket npm 9Router, current menunjuk ke rilis aktif
  current -> releases/<ver>
  data/                  DATA_DIR 9Router, dipertahankan saat uninstall
  settings.ini           konfigurasi, dipertahankan saat uninstall
  9router.log            log service
  install.log            log flash
```

### Kredit dan lisensi

- Module 9RouterAndroid dibuat oleh **OmmniDevv**, lisensi **MIT**
  (lihat file `LICENSE`).
- 9Router dibuat oleh decolua, lisensi MIT, diunduh dari npm saat flash.
- Node.js dibuat oleh Node.js contributors, lisensi bergaya MIT.
- glibc dan libstdc++ berlisensi LGPL, dibangun dari paket resmi Debian
  13 trixie aarch64 (libc6 2.41, libstdc++6 14.2.0, libgcc-s1 14.2.0).
- Module ini memakai pendekatan loader glibc yang umum untuk menjalankan
  biner Linux glibc di Android.

### Changelog

#### v1.0.4 (2026-10-28)

- Perbaikan tombol Action/WebUI KernelSU yang tidak muncul:
  webroot/index.html sebelumnya terbawa di zip dengan izin 660
  (tidak bisa dibaca aplikasi KernelSU sebagai user non-root),
  sekarang dipaksa 644 saat flash, action.sh dipaksa 755, dan
  folder webroot dipaksa 755.
- Catatan penting yang tidak bisa diperbaiki dari dalam zip:
  tombol Action/WebUI KernelSU hanya muncul kalau modulnya AKTIF
  (toggle menyala) dan sesudah reboot. Kalau toggle masih mati di
  daftar modul, nyalakan dulu lalu reboot, baru tombolnya muncul.
  WebUI juga bisa dibuka dari halaman detail modul (ketuk kartunya),
  bukan cuma dari daftar.

#### v1.0.4 (2026-10-28)

- Fix for the missing KernelSU Action/WebUI buttons:
  webroot/index.html used to ship in the zip as 660 (not readable
  by the KernelSU manager app as a non-root user); it is now forced
  to 644 at flash, action.sh to 755, and the webroot folder to 755.
- Important note that cannot be fixed from inside the zip:
  KernelSU only shows the Action/WebUI buttons when the module is
  ENABLED (toggle on) and after a reboot. If the toggle is still off
  in the module list, turn it on and reboot first. The WebUI button
  also lives on the module detail page (tap the card), not only in
  the list.

#### v1.0.3 (2026-10-28)

- WebUI hybrid: halaman yang sama bisa dibuka dari tombol WebUI di
  KernelSU (webroot/index.html) dan dari browser
  (http://127.0.0.1:20129/). Server WebUI jalan otomatis saat flash
  dan saat boot, jadi tidak perlu dinyalakan manual.
- Di WebUI bisa ganti/tambah provider untuk Hermes (pilih model dari
  daftar /v1/models, API key opsional, simpan langsung ke config
  Hermes) dan ubah pengaturan module (port, host, autostart, DoH,
  max_old_space). Kalau pengaturan yang butuh restart diubah,
  9router di-restart otomatis dari WebUI, tidak perlu restart manual.
- Dashboard bawaan 9router tetap ada terpisah di
  http://127.0.0.1:20128/dashboard, login tetap pakai password awal
  9router. WebUI module ini loopback saja, tidak dibuka ke LAN.

#### v1.0.3 (2026-10-28)

- Hybrid WebUI: the same page opens from the KernelSU WebUI button
  (webroot/index.html) and from a browser
  (http://127.0.0.1:20129/). The WebUI server starts automatically
  at flash and at boot, so no manual start is needed.
- From the WebUI you can change/add a provider for Hermes (pick a
  model from /v1/models, optional API key, saved straight to the
  Hermes config) and change module settings (port, host, autostart,
  DoH, max_old_space). Settings that need a restart restart 9router
  automatically from the WebUI, no manual restart needed.
- The built-in 9router dashboard stays separate at
  http://127.0.0.1:20128/dashboard, login still uses the 9router
  initial password. This module WebUI is loopback only.

#### v1.0.2 (2026-10-28)

- Exec via KernelSU seperti HermesAndroid: `su -c 9router` dan
  `su -c 9router.service status` langsung bisa dipakai setelah flash,
  tanpa harus reboot dulu. Sebelumnya link ke /data/adb/ksu/bin baru
  dibuat service.sh saat boot, dan overlay system/bin tidak selalu
  muncul di shell KernelSU.
- WebUI = dashboard bawaan 9router sendiri
  (http://127.0.0.1:20128/dashboard), bukan server baru, bukan port
  baru, dan tidak perlu nyala-ulang yang ribet. Login tetap pakai
  password awal 9router (lihat `su -c '9router password'`, atau
  `su -c '9router webui'` yang menyalakan server kalau belum jalan
  lalu menampilkan URL-nya). Action button juga membuka dashboard ini.

#### v1.0.2 (2026-10-28)

- KernelSU exec like HermesAndroid: `su -c 9router` and
  `su -c 9router.service status` work right after flashing, without
  waiting for a reboot. Previously the /data/adb/ksu/bin link was only
  created by service.sh at boot, and the system/bin overlay does not
  always show up in KernelSU shells.
- WebUI = the built-in 9router dashboard itself
  (http://127.0.0.1:20128/dashboard), not a new server, not a new
  port, and no complicated restart dance. Login still uses the
  9router initial password (see `su -c '9router password'`, or
  `su -c '9router webui'`, which starts the server if needed and
  prints the URL). The Action button opens this same dashboard.

#### v1.0.1 (2026-10-28)

- Perbaikan penting: ID module diubah dari `9routerandroid` menjadi
  `routerandroid`, karena KernelSU menolak ID yang diawali angka
  dengan pesan Invalid module ID. Nama repo dan nama module tetap
  9RouterAndroid, hanya ID internal yang berubah.
- Tidak ada perubahan fitur lain dari v1.0.0.

#### v1.0.0 (2026-10-28)

- Rilis pertama 9RouterAndroid oleh OmmniDevv.
- Module standalone untuk Magisk, KernelSU, dan APatch, aarch64.
- Runtime glibc dibundel, Node.js 22 LTS dipakai ulang dari HermesAndroid
  bila ada atau diunduh resmi bila belum ada.
- Instal 9Router dari npm dengan manajemen rilis, update, rollback,
  doctor, dan self-test saat flash.
- Dashboard loopback default, password awal acak, heap dibatasi 768 MB.
- Perintah `9router` lengkap dan tombol Action di manager.
- README dua bahasa, lisensi MIT, dan `update.json` untuk cek pembaruan.

---
## English

### About

9Router is an LLM gateway compatible with the OpenAI API. One local
endpoint can route requests to many providers, with automatic fallback
when a provider fails or hits a limit. 9RouterAndroid installs 9Router
as a service on the phone, without Termux and without proot.

After installation you get:

- Dashboard at `http://127.0.0.1:20128/dashboard`
- OpenAI-compatible API at `http://127.0.0.1:20128/v1`
- The root command `9router` for start, stop, status, update, and rollback
- A standalone runtime: glibc bundled in the module zip, plus Node.js
  22 LTS reused from HermesAndroid when present, or downloaded officially
  from nodejs.org when absent

### Requirements

- **aarch64** Android phone (ARM 64-bit). Other architectures are
  rejected at flash time.
- Rooted with Magisk, KernelSU, or APatch.
- Internet during flashing, because Node.js and the 9Router package are
  downloaded at that time. After installation, 9Router runs locally and
  does not need Termux.
- At least 500 MB free on `/data` at flash time. Usage after installation
  is about 120 MB when Node.js is reused, or about 300 MB at peak when
  Node.js also has to be downloaded.

### Installation

1. Download `9RouterAndroid-v1.0.4.zip` from
   [Releases](https://github.com/OmmniDevv/9RouterAndroid/releases).
2. Flash that zip in Magisk, KernelSU, or APatch Manager while online.
3. Wait for the flash log to finish. The module runs a one-time
   self-test by booting 9Router on a spare port to prove the runtime
   works on that phone.
4. Reboot, or run `su -c '9router start'`.
5. Press the Action button in the manager, or open
   `http://127.0.0.1:20128/dashboard` in the phone browser.
6. Log in with the initial password shown in the flash log and in
   `su -c '9router password'`, then **change that password in the
   dashboard as soon as possible**.

### Usage

#### Dashboard and API

- Dashboard: `http://127.0.0.1:20128/dashboard`
- API base: `http://127.0.0.1:20128/v1`
- For any OpenAI-compatible client: base URL
  `http://127.0.0.1:20128/v1`, API key taken from the dashboard, model
  chosen from the model list in the dashboard.

Add providers and create API keys in the dashboard as usual. Do not
share your 9Router API key with others, and do not expose the dashboard
to another network unless you understand the risk.

#### CLI commands

All commands run as root, for example `su -c '9router status'`.

| Command | Purpose |
| --- | --- |
| `9router status` | Show status, version, bind address, and autostart |
| `9router start` | Start 9Router |
| `9router stop` | Stop 9Router |
| `9router restart` | Stop and start again |
| `9router log` | Show the log, add `-f` to follow it |
| `9router url` | Show dashboard and API URLs |
| `9router password` | Show the initial dashboard password |
| `9router config` | Show configuration |
| `9router config set KEY VALUE` | Change one key, then `9router restart` |
| `9router update` | Update 9Router from npm, with automatic rollback if the new release fails to start |
| `9router update --check` | Check for an update without installing |
| `9router update --version X` | Install a specific 9Router version |
| `9router rollback` | Return to the previous 9Router release |
| `9router doctor` | Diagnose runtime, disk, and service health |
| `9router selftest` | Boot once on a spare port for testing |
| `9router version` | Show the 9Router version and the module version |
| `9router models` | List models |
| `9router models <filter>` | List models matching the filter |

#### Configuration

The configuration file is `/data/adb/9router/settings.ini`. Change it
with `9router config set KEY VALUE`, then `9router restart`.

| Key | Default | Meaning |
| --- | --- | --- |
| `port` | `20128` | Dashboard and API port |
| `host` | `127.0.0.1` | Loopback only. Change to `0.0.0.0` only if you know the dashboard becomes reachable from the local network, and change the password first |
| `autostart` | `true` | Start automatically on every boot |
| `max_old_space` | `768` | V8 heap limit in MB, tuned for a phone |
| `initial_password` | random per device | Initial dashboard password until you change it in the dashboard |
| `doh` | `auto` | DNS-over-HTTPS inside the Node process, `off` to disable |
| `hermes_dir` | `/data/adb/hermes` | Location of HermesAndroid when present |

#### Connecting HermesAndroid (optional)

If HermesAndroid is installed and you want Hermes to use 9Router as a
provider, run:

```sh
su -c '9router models'
su -c '9router link-hermes --model <provider/model>'
su -c 'hermes.service restart'
```

`link-hermes` creates an API key named `hermes-android` in 9Router,
writes the base URL and key into the Hermes configuration, and keeps
the original Hermes configuration files with a `.routerandroid.bak`
suffix. This step is optional and only changes the Hermes configuration
when you run it yourself.

### Updates and versioning

The module versioning rule, and the promise for every later release:

- Every module update **must** raise `version` in `module.prop` and
  raise `versionCode` by 1.
- The first version is **1.0.0** with `versionCode` **100**.
- Every release zip is always named `9RouterAndroid-v<version>.zip`.
- `update.json` on the `main` branch is always updated to the newest
  version, so managers that support updateJson can check for updates.
- The changelog for each release is on the GitHub Releases page.

To update 9Router inside the module without updating the module itself,
use `su -c '9router update'`. If a new release fails to start, the
module automatically restores the previous release. To roll back
manually, use `su -c '9router rollback'`.

To update the module to a newer version, flash the new zip in the
manager like a normal install. Data in `/data/adb/9router/data` and
`settings.ini` are kept on update.

### Uninstallation

Remove the module from Magisk, KernelSU, or APatch Manager as usual.
The 9Router process is stopped and re-downloadable runtime files are
removed, but the following are kept so a reinstall can pick up where
you left off:

- `/data/adb/9router/data` (database, provider credentials, API keys)
- `/data/adb/9router/settings.ini`

If you want a full wipe, delete both locations manually as root after
removing the module.

### Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| Flash fails, unsupported architecture | The phone is not aarch64. This module is aarch64 only |
| Flash fails, not enough space | Free `/data` until at least 500 MB is available, then flash again |
| Flash fails, no internet | Node.js and the 9Router package are downloaded at flash time. Connect to the internet and flash again |
| Self-test fails at flash time | See `/data/adb/9router/selftest.log` and `/data/adb/9router/install.log`, then run `su -c '9router doctor'` after reboot |
| Dashboard does not open | Check the service with `su -c '9router status'`, then `su -c '9router start'` and `su -c '9router log'` |
| Password forgotten | The initial password is in `su -c '9router password'`. If you changed it in the dashboard, the new password is the one that counts |
| 9Router update fails to start | The module rolls back automatically. Check with `su -c '9router status'` and `su -c '9router rollback'` if needed |
| Phone aggressively kills background processes | Exempt the root manager and this process from battery optimization if needed |

### Security

- The service binds to loopback `127.0.0.1` by default. Do not change
  it to `0.0.0.0` without changing the dashboard password first.
- The initial password is random per device and stored in
  `/data/adb/9router/settings.ini` with mode 600. Still change it in
  the dashboard after the first login.
- This module does not change iptables, does not install a system-level
  DNS redirect, and does not install a system proxy. DNS-over-HTTPS
  runs only inside the 9Router Node process, and can be disabled with
  `doh=off`.
- This module does not send user data to any server except downloads
  at flash time (nodejs.org and the npm registry) and provider
  connections you configure yourself in the 9Router dashboard.

### Files on the phone

```text
/data/adb/9router/
  bin/9router            control script, also linked into /data/adb/ksu/bin or /data/adb/ap/bin
  node/bin/node          wrapper to the glibc loader, node.real is the real Node binary
  glibc/lib/             glibc loader and libraries
  releases/<ver>/        npm 9Router package, current points to the active release
  current -> releases/<ver>
  data/                  9Router DATA_DIR, kept on uninstall
  settings.ini           configuration, kept on uninstall
  9router.log            service log
  install.log            flash log
```

### Credits and license

- The 9RouterAndroid module is made by **OmmniDevv**, **MIT** license
  (see the `LICENSE` file).
- 9Router is made by decolua, MIT license, downloaded from npm at
  flash time.
- Node.js is made by Node.js contributors, MIT-style license.
- glibc and libstdc++ are LGPL licensed, built from official Debian
  13 trixie aarch64 packages (libc6 2.41, libstdc++6 14.2.0,
  libgcc-s1 14.2.0).
- This module uses the common glibc-loader approach to run a glibc
  Linux binary on Android.

### Changelog

#### v1.0.1 (2026-10-28)

- Perbaikan penting: ID module diubah dari `9routerandroid` menjadi
  `routerandroid`, karena KernelSU menolak ID yang diawali angka
  dengan pesan Invalid module ID. Nama repo dan nama module tetap
  9RouterAndroid, hanya ID internal yang berubah.
- Tidak ada perubahan fitur lain dari v1.0.0.

#### v1.0.0 (2026-10-28)

- First release of 9RouterAndroid by OmmniDevv.
- Standalone module for Magisk, KernelSU, and APatch, aarch64.
- Bundled glibc runtime, Node.js 22 LTS reused from HermesAndroid
  when present or downloaded officially when absent.
- 9Router installed from npm with release management, update,
  rollback, doctor, and flash-time self-test.
- Loopback dashboard by default, random initial password, heap
  limited to 768 MB.
- Full `9router` command set and manager Action button.
- Bilingual README, MIT license, and `update.json` for update checks.

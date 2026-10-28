# PRD: 9RouterAndroid, module KernelSU/Magisk untuk 9Router (gabungan, v1.0.0)

## Tujuan
Satu module root Android yang memasang 9Router (decolua/9router, gateway
LLM OpenAI-compatible) di HP Android root, tanpa bergantung module lain
untuk jalan. Basis skrip gabungan dari versi percobaan user dan draf awal,
dimodifikasi menjadi produk OmmniDevv yang matang: branding OmmniDevv,
README dua bahasa lengkap, lisensi MIT, banner GitHub, dan aturan versi
yang ditegakkan di setiap rilis.

## Pengguna dan perangkat
- HP Android aarch64, sudah root dengan Magisk, KernelSU, atau APatch.
- User: OmniDev, HP utama Infinix Note 30 Pro. Uji runtime di HP adalah
  gerbang QA terakhir, karena VM ini bukan Android.

## Kebutuhan fungsional
1. Flash module dari manager root, tanpa Termux dan tanpa proot.
2. Saat flash: cek aarch64, cek ruang kosong minimal 500 MB, ekstrak
   glibc dari zip, pakai ulang Node.js Hermes bila ada atau unduh
   Node.js 22 LTS resmi, instal 9Router dari npm dengan manajemen
   rilis, lalu self-test sekali di port cadangan.
3. Setelah boot: service autostart menjalankan 9Router di loopback saja,
   `http://127.0.0.1:20128/dashboard`, API di
   `http://127.0.0.1:20128/v1`.
4. Tombol Action di manager: status, mulai bila berhenti, buka dashboard.
5. Perintah root `9router` lengkap: start, stop, restart, status, log,
   url, password, config, update, rollback, doctor, selftest, version,
   models, link-hermes (opsional).
6. Update 9Router di dalam module dengan rollback otomatis bila gagal
   start. Update module dengan flash zip versi baru.
7. Uninstall menghentikan proses dan menghapus runtime yang bisa
   diunduh ulang, tetapi mempertahankan `/data/adb/9router/data` dan
   `settings.ini`.

## Kebutuhan non-fungsional dan keamanan
- Bind loopback saja secara default. Ubah ke 0.0.0.0 hanya dengan
  sadar risiko dan setelah ganti password.
- Password awal acak per perangkat, mode 600, tetap wajib diganti di
  dashboard setelah login pertama.
- Tidak ada redirect DNS level sistem, tidak ada iptables, tidak ada
  proxy sistem. DoH hanya di dalam proses Node dan bisa dimatikan.
- Data user tidak pernah ikut ke repo, zip rilis, atau log publik.
- Tidak ada atribusi asisten di commit, pesan commit, atau file repo.
  Nama yang tampil hanya OmmniDevv sebagai pembuat module, dan kredit
  upstream yang sah (9Router, Node.js, glibc LGPL).

## Penomoran versi (aturan keras)
- Versi awal 1.0.0, versionCode 100.
- Setiap pembaruan module wajib menaikkan version dan versionCode +1,
  memperbarui `update.json`, membuat zip bernama
  `9RouterAndroid-v<version>.zip`, dan membuat GitHub Release dengan
  tag `v<version>` yang melampirkan zip itu.
- Tidak ada rilis tanpa versi, tidak ada versi yang dipakai dua kali.

## Kriteria penerimaan v1.0.0
- `sh -n` lolos untuk semua skrip shell, `node --check` lolos untuk
  dua file .cjs.
- Zip berisi module.prop, customize.sh, service.sh, action.sh,
  uninstall.sh, META-INF, system/bin/9router, scripts/, glibc.tar.gz.
- glibc.tar.gz berisi loader dan pustaka aarch64 lengkap, termasuk
  NSS dan libresolv, bukan hanya set minimal.
- module.prop: id routerandroid, version 1.0.0, versionCode 100,
  author OmmniDevv, updateJson mengarah ke raw GitHub main.
- Repo GitHub OmmniDevv/9RouterAndroid berisi README dua bahasa,
  banner, LICENSE MIT, update.json, dan dokumen proyek ini.
- Tidak ada kata terlarang atribusi asisten di seluruh repo yang
  di-push, diverifikasi dengan grep sebelum push.
- Runtime di HP belum teruji di perangkat nyata sampai user flash dan
  melaporkan hasil self-test. Itu dinyatakan jujur di laporan, bukan
  diklaim sudah jalan di HP.

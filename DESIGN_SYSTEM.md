# DESIGN_SYSTEM.md (9RouterAndroid)

Module ini tidak punya UI sendiri. Satu-satunya antarmuka visual adalah
dashboard web bawaan 9Router di `http://127.0.0.1:20128/dashboard`, yang
tidak diubah oleh module ini. Dokumen ini mengatur permukaan yang memang
milik module: log flash, pesan Action, dan README.

## Pesan terminal (flash dan Action)
- Awalan pesan memakai `- ` untuk info dan `ERROR: ` untuk kegagalan.
- Satu baris, satu fakta. Jangan memakai banner ASCII panjang, warna
  ANSI, atau emoji di log instalasi, karena output manager root sering
  dipotong dan dibaca ulang dari log.
- Pesan gagal selalu menyebut apa yang gagal dan file lognya:
  `/data/adb/9router/install.log` atau `/data/adb/9router/service.log`.

## README
- Judul, apa itu module, syarat (root, aarch64, internet saat flash),
  cara instal, cara pakai, cara update, cara uninstall, dan peringatan
  keamanan ada di satu README, tanpa jargon yang tidak dijelaskan.
- Peringatan password dashboard default 123456 ditulis di bagian atas
  cara pakai, bukan disembunyikan di catatan kaki.
- Tautan yang dicantumkan hanya tautan resmi: repo upstream 9Router,
  nodejs.org, dan halaman rilis module ini.

## Penamaan
- ID module: `9routerandroid` (huruf kecil, tanpa tanda hubung, sesuai
  aturan module.prop).
- Nama repo GitHub: `9RouterAndroid`.
- Nama file zip rilis: `9RouterAndroid-v<version>.zip`, contoh
  `9RouterAndroid-v1.0.0.zip`.

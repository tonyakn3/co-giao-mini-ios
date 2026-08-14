# Cô Giáo Mini — iOS native, free sideload

Đây là project iOS/iPadOS native bằng SwiftUI. App không cần PC chạy server sau khi cài.

## Kiến trúc

iPhone/iPad
→ Gemini API key lưu trong iOS Keychain
→ app mint ephemeral token
→ Gemini Live WebSocket
→ microphone/audio realtime

Memory học tập lưu local trên thiết bị bằng UserDefaults.

## Build IPA miễn phí bằng GitHub Actions

1. Tạo tài khoản GitHub miễn phí.
2. Tạo **public repository** mới, ví dụ `co-giao-mini-ios`.
3. Upload toàn bộ nội dung thư mục này lên repo.
4. GitHub Actions sẽ tự chạy workflow `Build unsigned iOS IPA`.
5. Vào tab **Actions** → build mới nhất → tải artifact `CoGiaoMini-unsigned-IPA`.
6. Giải nén artifact để lấy `CoGiaoMini-unsigned.ipa`.

Public repository dùng standard GitHub-hosted runners thì GitHub Actions minutes miễn phí.

## Cài lên iPhone/iPad bằng Windows + Sideloadly

1. Cài Sideloadly trên Windows.
2. Cắm iPhone/iPad vào PC bằng USB và chọn **Trust** khi iOS hỏi.
3. Mở Sideloadly.
4. Kéo `CoGiaoMini-unsigned.ipa` vào Sideloadly.
5. Nhập Apple ID miễn phí của bạn và sideload.
6. Nếu iOS yêu cầu, bật Developer Mode / trust developer profile.
7. Mở Cô Giáo Mini.
8. Vào ⚙️, nhập Gemini API key một lần.
9. Bấm **Nói với Cô Giáo Mini**.

## Giới hạn Apple ID miễn phí

App được ký bằng Apple ID miễn phí có provisioning khoảng 7 ngày. Sau đó phải refresh/re-sideload. Đây là giới hạn Apple Personal Team.

Sideloadly có auto-refresh khi Windows/Sideloadly hoạt động và thiết bị có thể kết nối phù hợp.

## Gemini API key

Không bundle key trong source. Key được nhập trên thiết bị và lưu trong Keychain.
Không gửi hoặc chụp key.

## Chức năng hiện có

- Voice realtime Gemini Live.
- Hiểu tiếng Việt, tiếng Anh, và câu trộn Việt/Anh.
- Cô Giáo Mini ưu tiên tiếng Anh đơn giản, dùng tiếng Việt khi Hà Anh cần.
- Caption lượt nói hiện tại.
- Ảnh cô giáo tĩnh.
- Nhớ tên Hà Anh.
- Nhớ sở thích, từ vựng và lỗi học tập có chọn lọc.
- Open-world conversation phù hợp trẻ 6 tuổi.
- Không App Store.

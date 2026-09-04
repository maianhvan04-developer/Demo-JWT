# JWT Finance Security Lab

Demo xác thực và phân quyền API bằng JWT với **Keycloak + API Gateway + Finance API + PostgreSQL**.

Gateway và Finance API cùng kiểm tra chữ ký RS256 qua JWKS, thời hạn `exp`, issuer `iss`, audience `aud` và loại token. Finance API kiểm tra thêm role `finance.read` trước khi đọc dữ liệu tài khoản.

> Toàn bộ tài khoản, mật khẩu và dữ liệu trong project là dữ liệu giả lập cho lab. Không dùng cấu hình `start-dev`, HTTP hoặc các mật khẩu này trong production.

## 1. Chuẩn bị

Cần cài Docker Desktop và Docker Compose.

Tạo file cấu hình local trên PowerShell:

```powershell
Copy-Item .env.example .env
```

Sau đó thay hai giá trị `CHANGE_ME` trong `.env`. File `.env` đã được `.gitignore` loại trừ và không được đưa vào bài nộp. Workspace hiện tại đã có sẵn `.env` với thông tin giả lập để chạy demo.

## 2. Khởi động

Chạy toàn bộ demo tự động trên Windows (build, health, network, 10 test JWT, refresh rotation và logout):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo.ps1
```

Hoặc chỉ khởi động stack:

```powershell
docker compose up --build -d
docker compose ps
```

Đợi bốn service ở trạng thái `healthy`:

- Keycloak: http://localhost:8080
- API Gateway: http://localhost:3000
- Finance API: chỉ truy cập nội bộ qua Gateway
- PostgreSQL: chỉ truy cập nội bộ trong mạng dữ liệu

Kiểm tra toàn bộ chuỗi Gateway → Finance API → PostgreSQL:

```powershell
curl.exe http://localhost:3000/health
```

Kết quả mong đợi:

```json
{
  "ok": true,
  "service": "api-gateway",
  "dependencies": {
    "financeApi": "ok"
  }
}
```

## 3. Demo 10 trường hợp JWT

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

Linux, macOS hoặc Git Bash:

```bash
chmod +x ./scripts/test.sh ./scripts/session-test.sh
./scripts/test.sh
```

| TC | Trường hợp | Kết quả |
|---|---|---:|
| 01 | Không gửi token | 401 |
| 02 | Alice có token hợp lệ và role `finance.read` | 200 |
| 03 | Bob có token hợp lệ nhưng thiếu role | 403 |
| 04 | Token sai audience | 401 |
| 05 | Token từ realm/issuer khác | 401 |
| 06 | JWT sai định dạng | 401 |
| 07 | Header thiếu scheme `Bearer` | 401 |
| 08 | Dùng refresh token để gọi API | 401 |
| 09 | Token hợp lệ gọi profile | 200 |
| 10 | Access token hết hạn | 401 |

Script tự so sánh HTTP status thực tế với kết quả mong đợi. TC10 chờ 36 giây vì access token có thời gian sống 30 giây và API cho phép sai lệch đồng hồ 5 giây.

## 4. Demo refresh rotation và thu hồi phiên

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\session-test.ps1
```

Linux, macOS hoặc Git Bash:

```bash
./scripts/session-test.sh
```

Script chứng minh:

- Refresh token hợp lệ cấp được bộ token mới.
- Refresh token cũ không được tái sử dụng.
- OIDC logout thu hồi phiên.
- Refresh token bị từ chối sau khi logout.

## 5. Kiểm tra PostgreSQL

Liệt kê ba tài khoản giả lập:

```powershell
docker compose exec postgres psql -U lab -d finance -c "SELECT id, owner, account_no, balance FROM accounts ORDER BY account_no;"
```

PostgreSQL không publish cổng `5432` ra host. Chỉ Keycloak và Finance API nằm trong network `data` mới kết nối được database.

## 6. Kiểm tra network và log

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\network-test.ps1
docker network inspect jwt-demo-edge
docker network inspect jwt-demo-data
docker compose logs --tail 50 api-gateway finance-api keycloak postgres
```

Thiết kế chi tiết, trust boundary và bảng giao tiếp nằm tại [docs/DEMO-DESIGN.md](docs/DEMO-DESIGN.md).

## 7. Tài khoản giả lập

- Keycloak Admin: giá trị trong `.env`
- Alice: `alice / Alice@123` — có role `finance.read`
- Bob: `bob / Bob@123` — không có role `finance.read`
- Eve: `eve / Eve@123` — thuộc realm `other-lab`

## 8. Dừng và dọn dẹp

Dừng nhưng giữ dữ liệu PostgreSQL:

```powershell
docker compose down
```

Xóa toàn bộ dữ liệu lab và khởi tạo lại từ `postgres/init.sql` cùng các realm JSON:

```powershell
docker compose down -v
docker compose up --build -d
```

Lệnh `down -v` xóa volume `jwt-demo-postgres-data`; chỉ dùng khi muốn reset dữ liệu giả lập.

## 9. Cấu trúc project

```text
.
├── compose.yaml
├── .env.example
├── api-gateway/
├── finance-api/
├── keycloak/
├── postgres/
│   └── init.sql
├── scripts/
│   ├── test.ps1
│   ├── test.sh
│   ├── session-test.ps1
│   ├── session-test.sh
│   ├── network-test.ps1
│   └── demo.ps1
└── docs/
    └── DEMO-DESIGN.md
```

Các image nền đều ghim phiên bản: PostgreSQL `17.11-alpine`, Keycloak `26.7.3` và Node.js `22.23.2-alpine`.

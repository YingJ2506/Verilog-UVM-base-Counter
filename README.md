# Verilog-UVM-base-Counter
Verilog project - UVM base Counter

# 驗證專案：類 UVM 計數器驗證平台

# 專案簡介
本專案旨在驗證一個 8 位元計數器（Counter DUT），並以自行開發的方式，實現一個遵循 UVM (Universal Verification Methodology) 核心概念的驗證平台，包含 Driver、Monitor、Sequencer 和 Scoreboard 等元件。此專案展現了對模組化、自動化與物件導向驗證思維的理解。

# 功能敘述
設計 (DUT)：一個可向上或向下計數的 8 位元計數器。
- 向上計數 (mode = 1)：在 en 為高電位時，count_out 每個時脈週期加 1。
- 向下計數 (mode = 0)：在 en 為高電位時，count_out 每個時脈週期減 1。
- 在en為低電位時，count_out不變。
- 支援歸零 (rst_n) 功能。

# 驗證環境設計
本驗證平台由多個模組組成，體現了 UVM 的分層架構：
- transaction：負責產生隨機的 en 和 mode 資料。
- Sequence：負責控制整個測試流程，並透過握手訊號來協調 Driver 的行為。
- Driver：將transaction產生的資料數據驅動到 DUT 的輸入埠。
- Monitor：獨立地觀察 DUT 的輸入與輸出訊號，並將資料傳送給 Scoreboard。
- Scoreboard：根據 en 和 mode，獨立地預測 DUT 的輸出值，並與 Monitor 傳來的實際值進行比對。
- Environment：整合所有驗證元件，協調它們的運行時序。

# 測試項目與目標
- 功能正確性驗證：確保計數器在向上和向下計數模式下，其輸出值與預期值一致。
- 隨機化測試：利用 $urandom 產生隨機的 en 和 mode 組合，以提高測試覆蓋率。
- 自動化測試：實現自動化的測試流程，從隨機資料生成、DUT 驅動，到結果比對與報告，無需手動介入。
- 精準的測試報告：最終能輸出精確的 pass 與 fail 總數，證明 DUT 行為的正確性。
- 使用EDAplayground(Icarus verilog + EPWave)進行模擬與驗證

# 模擬結果
- 運行 counter_environment 模組，成功產生 15 個隨機交易。
- 驗證平台正確地比對了每個時脈週期的 DUT 輸出。
- 最終報告顯示，fail_count 為 0，測試成功通過。

EPWave 波型圖可視化測試結果（見附圖）
<img width="2286" height="508" alt="image" src="https://github.com/user-attachments/assets/347abf13-4ca5-451e-900e-353a4559b9de" />


# 修正心得
- **從 class 到 module 的框架轉換**

在專案開發之初，我曾嘗試使用 SystemVerilog 的 class 與 interface 來搭建驗證環境，以實現物件導向的架構。然而，由於我使用的模擬器（如 Icarus Verilog）版本或配置上的限制，無法完全支援這些高級特性。這讓我不得不回歸到最基礎的 module 形式。不過這個過程仍然讓我深刻體會到以uvm為base的概念實作，也強化了我對 Verilog module 通訊和task的掌握。

- **釐清時脈延遲與比對邏輯**

在開發初期，我觀察到 scoreboard 的 fail_count 數值異常。透過詳細分析波形圖，我發現問題源於時脈域的延遲。由於 monitor 在一個時脈週期後才觀察到 driver 驅動的訊號值，這導致 scoreboard 在比對時，實際接收到的 en、mode 和 count_out 總是比我的預期慢一個週期。為了解決這個時序不匹配問題，我在 monitor 中加入了延遲暫存器 (en_dly, mode_dly)，確保傳送給 scoreboard 的資料是與 DUT 在同一時間點的行為，從而讓比對邏輯能夠精確判斷。

- **測試收尾時序與訊號協調**

從波型圖發現在測試結束時，driver 和 monitor 的訊號仍在運行。這造成了不必要的模擬時間浪費。我透過修改 environment 的控制邏輯，讓它在 sequence 結束後，精確地關閉所有訊號。這確保了整個驗證平台的同步，並實現了乾淨的測試收尾。

- **釐清多餘的變數與記憶體宣告**

在重新檢查程式碼時，我意識到程式碼中存在多餘的變數宣告，例如取消同時使用trans_id 和 trans_id_register 陣列來儲存ID，且將單一位元的 en 和 mode 訊號宣告從 16 位元改為1位元的記憶體。透過反思程式碼風格避免冗餘宣告，並將陣列的位元寬度設定為與實際訊號完全匹配，以提高程式碼的可讀性和效率。

# 待優化
- 改寫為 Class-based：將所有模組（如 counter_transaction、driver 等）用 SystemVerilog class 實現，以完全符合 UVM 的物件導向設計原則。
- 導入 TLM：使用 TLM (Transaction Level Modeling) 埠來取代模組埠和全域變數，實現更抽象的元件通訊。
- 增加測試項目：擴展測試計畫，涵蓋更複雜的情境，例如隨機的 en 脈衝寬度測試、隨機延遲測試等。
- 分離 Sequence 與 Sequencer 職責：將 sequence 和 sequencer 的功能拆分。sequence 專注於產生交易，sequencer 則作為仲裁與傳輸的橋樑，提升專案彈性。
- 升級為物件導向傳輸：優化 driver 直接從陣列讀取數據的方式。改為讓 sequence 產生交易物件並透過 sequencer 傳輸給 driver，實現更佳的可擴展性。
- 封裝驗證元件：將 scoreboard 和 transaction pool 封裝進 environment 模組。這能使 environment 成為可獨立重用的單元，提升整個驗證平台的模組化程度。

# 更版紀錄
1. v1.0---初始版本，完成基本功能驗證

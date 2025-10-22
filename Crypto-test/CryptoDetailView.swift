//
//  CryptoDetailView.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

// Views/CryptoDetailView.swift
import SwiftUI
import Charts

struct CryptoDetailView: View {
    let cryptoId: String
    @ObservedObject var listViewModel: CryptoListViewModel
    @State private var cryptocurrency: CryptoCurrency?
    @State private var priceHistory: [PriceHistory] = []
    @State private var selectedTimeRange = 24
    @State private var isLoadingHistory = false
    @State private var isLoadingCrypto = false
    
    init(cryptoId: String, listViewModel: CryptoListViewModel) {
        self.cryptoId = cryptoId
        self.listViewModel = listViewModel
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if let crypto = cryptocurrency {
                    // Header Section
                    headerSection(crypto: crypto)
                    
                    // Price Card
                    priceCard(crypto: crypto)
                    
                    // Chart Section
                    chartSection(crypto: crypto)
                    
                    // Statistics Grid
                    statisticsGrid(crypto: crypto)
                    
                    // Market Info
                    marketInfoSection(crypto: crypto)
                } else {
                    loadingView
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(cryptocurrency?.name ?? "Crypto Details")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshData()
        }
        .task {
            await loadInitialData()
        }
        .onReceive(listViewModel.$lastUpdated) { _ in
            Task {
                await loadCryptoData()
            }
        }
    }
    
    // MARK: - View Components
    
    private func headerSection(crypto: CryptoCurrency) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                CachedAsyncImage(
                    url: URL(string: crypto.image),
                    placeholder: Image(systemName: "dollarsign.circle")
                )
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(crypto.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(crypto.symbol.uppercased())
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
    }
    
    private func priceCard(crypto: CryptoCurrency) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formattedPrice(crypto.currentPrice))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: (crypto.priceChangePercentage24h ?? 0) >= 0 ? "arrow.up.forward" : "arrow.down.forward")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(formattedPriceChange(crypto.priceChangePercentage24h))
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(priceChangeColor(crypto.priceChangePercentage24h))
            }
            
            Text("Current Price")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func chartSection(crypto: CryptoCurrency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Chart")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                timeRangePicker
            }
            
            if priceHistory.isEmpty {
                chartPlaceholder
            } else {
                chartContainer(crypto: crypto)
                    .frame(height: 220)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            Text("1H").tag(1)
            Text("6H").tag(6)
            Text("12H").tag(12)
            Text("24H").tag(24)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _ in
            Task {
                await loadPriceHistory()
            }
        }
    }
    
    private func chartContainer(crypto: CryptoCurrency) -> some View {
        ZStack {
            Color.clear
            lineChart(crypto: crypto)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    private func lineChart(crypto: CryptoCurrency) -> some View {
        let isPositive = (crypto.priceChangePercentage24h ?? 0) >= 0
        
        return Chart {
            ForEach(priceHistory, id: \.timestamp) { history in
                LineMark(
                    x: .value("Time", history.timestamp),
                    y: .value("Price", history.price)
                )
                .foregroundStyle(isPositive ? Color.green.gradient : Color.red.gradient)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                // Add point marks for the last value
                if history.timestamp == priceHistory.last?.timestamp {
                    PointMark(
                        x: .value("Time", history.timestamp),
                        y: .value("Price", history.price)
                    )
                    .foregroundStyle(isPositive ? Color.green : Color.red)
                    .symbolSize(40)
                }
            }
        }
        .chartYScale(domain: calculateSmartYAxisRange(currentPrice: crypto.currentPrice))
        .chartXAxis(content: chartXAxis)
        .chartYAxis(content: chartYAxis)
    }
    
    private func chartXAxis() -> some AxisContent {
        AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
            if let date = value.as(Date.self) {
                AxisValueLabel {
                    Text(timeAxisLabel(for: date))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            AxisGridLine()
                .foregroundStyle(Color.gray.opacity(0.2))
            AxisTick()
                .foregroundStyle(Color.gray.opacity(0.3))
        }
    }
    
    private func chartYAxis() -> some AxisContent {
        AxisMarks(preset: .extended, values: .automatic(desiredCount: 5)) { value in
            AxisValueLabel {
                if let price = value.as(Double.self) {
                    Text(price.formattedChartPrice)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            AxisGridLine()
                .foregroundStyle(Color.gray.opacity(0.2))
        }
    }
    
    // زمان‌های مشخص برای نمایش روی محور X
    private func getTimeAxisValues() -> [Date] {
        let now = Date()
        var times: [Date] = []
        
        switch selectedTimeRange {
        case 1: // 1 ساعت - 4 نقطه: الان، 20 دقیقه قبل، 40 دقیقه قبل، 1 ساعت قبل
            times = [
                now.addingTimeInterval(-60 * 60),  // 1 ساعت قبل
                now.addingTimeInterval(-40 * 60),  // 40 دقیقه قبل
                now.addingTimeInterval(-20 * 60),  // 20 دقیقه قبل
                now                                  // الان
            ]
            
        case 6: // 6 ساعت - 4 نقطه: الان، 2 ساعت قبل، 4 ساعت قبل، 6 ساعت قبل
            times = [
                now.addingTimeInterval(-6 * 60 * 60),  // 6 ساعت قبل
                now.addingTimeInterval(-4 * 60 * 60),  // 4 ساعت قبل
                now.addingTimeInterval(-2 * 60 * 60),  // 2 ساعت قبل
                now                                      // الان
            ]
            
        case 12: // 12 ساعت - 4 نقطه: الان، 4 ساعت قبل، 8 ساعت قبل، 12 ساعت قبل
            times = [
                now.addingTimeInterval(-12 * 60 * 60), // 12 ساعت قبل
                now.addingTimeInterval(-8 * 60 * 60),  // 8 ساعت قبل
                now.addingTimeInterval(-4 * 60 * 60),  // 4 ساعت قبل
                now                                      // الان
            ]
            
        case 24: // 24 ساعت - 4 نقطه: 00:00, 6:00, 12:00, 18:00
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            
            times = [
                today.addingTimeInterval(0),          // 00:00
                today.addingTimeInterval(6 * 60 * 60),  // 06:00
                today.addingTimeInterval(12 * 60 * 60), // 12:00
                today.addingTimeInterval(18 * 60 * 60)  // 18:00
            ]
            
            // اگر الان بعد از 18:00 هست، نقطه آخر را الان قرار بده
            if now > times[3] {
                times[3] = now
            }
            
        default:
            times = [now]
        }
        
        return times.sorted()
    }
    
    // فرمت نمایش زمان برای محور X
    private func timeAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case 1: // 1 ساعت - نمایش دقیقه
            formatter.dateFormat = "HH:mm"
            
        case 6, 12: // 6 و 12 ساعت - نمایش ساعت
            formatter.dateFormat = "HH:mm"
            
        case 24: // 24 ساعت - نمایش ساعت ساده
            formatter.dateFormat = "HH:mm"
            
        default:
            formatter.dateFormat = "HH:mm"
        }
        
        // برای زمان جاری، "اکنون" نمایش بده
        if selectedTimeRange != 24 && abs(date.timeIntervalSince(Date())) < 60 {
            return "اکنون"
        }
        
        return formatter.string(from: date)
    }
    
    private var chartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Collecting Price Data")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Chart will appear as data accumulates")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func statisticsGrid(crypto: CryptoCurrency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Market Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !priceHistory.isEmpty {
                let stats = calculatePriceStats()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "24H High",
                        value: stats.high.formattedCurrency,
                        icon: "arrow.up",
                        color: .green
                    )
                    
                    StatCard(
                        title: "24H Low",
                        value: stats.low.formattedCurrency,
                        icon: "arrow.down",
                        color: .red
                    )
                    
                    StatCard(
                        title: "Average",
                        value: stats.average.formattedCurrency,
                        icon: "chart.bar",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Volatility",
                        value: String(format: "%.2f%%", stats.volatility * 100),
                        icon: "chart.xyaxis.line",
                        color: .orange
                    )
                }
            } else {
                Text("Market data loading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func marketInfoSection(crypto: CryptoCurrency) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Info")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                infoRow(
                    title: "Time Range",
                    value: "\(selectedTimeRange) hours",
                    icon: "clock"
                )
                
                infoRow(
                    title: "Last Updated",
                    value: compactLastUpdatedTime(),
                    icon: "calendar"
                )
                
                if !priceHistory.isEmpty {
                    let firstPoint = priceHistory.first!
                    let lastPoint = priceHistory.last!
                    let change = ((lastPoint.price - firstPoint.price) / firstPoint.price) * 100
                    
                    infoRow(
                        title: "Period Performance",
                        value: "\(change >= 0 ? "+" : "")\(String(format: "%.2f", change))%",
                        icon: change >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        valueColor: change >= 0 ? .green : .red
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func infoRow(title: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
    
    // Compact time format for last updated that fits in one line
    private func compactLastUpdatedTime() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: now)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Market Data...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        await loadCryptoData()
        await loadPriceHistory()
    }
    
    private func refreshData() async {
        await loadCryptoData()
        await loadPriceHistory()
    }
    
    private func loadCryptoData() async {
        isLoadingCrypto = true
        cryptocurrency = await listViewModel.getCryptoDetail(by: cryptoId)
        isLoadingCrypto = false
    }
    
    private func loadPriceHistory() async {
        isLoadingHistory = true
        priceHistory = await listViewModel.getPriceHistory(for: cryptoId, hours: selectedTimeRange)
        isLoadingHistory = false
    }
    
    // MARK: - Helper Methods
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = price < 1 ? 6 : 2
        return formatter.string(from: NSNumber(value: price)) ?? "$0.00"
    }
    
    private func formattedPriceChange(_ change: Double?) -> String {
        guard let change = change else { return "N/A" }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))%"
    }
    
    private func priceChangeColor(_ change: Double?) -> Color {
        guard let change = change else { return .secondary }
        return change >= 0 ? .green : .red
    }
    
    private func calculateSmartYAxisRange(currentPrice: Double) -> ClosedRange<Double> {
        guard !priceHistory.isEmpty else {
            let range = currentPrice * 0.05
            return (currentPrice - range)...(currentPrice + range)
        }
        
        let prices = priceHistory.map { $0.price }
        let dataMin = prices.min() ?? currentPrice
        let dataMax = prices.max() ?? currentPrice
        
        let visibleMin = min(dataMin, currentPrice)
        let visibleMax = max(dataMax, currentPrice)
        let visibleRange = visibleMax - visibleMin
        
        let basePadding: Double = visibleRange > 0 ? visibleRange * 0.1 : currentPrice * 0.03
        let minPadding = currentPrice * 0.01
        let actualPadding = max(basePadding, minPadding)
        
        return (visibleMin - actualPadding)...(visibleMax + actualPadding)
    }
    
    private func calculatePriceStats() -> (high: Double, low: Double, average: Double, volatility: Double) {
        guard !priceHistory.isEmpty else { return (0, 0, 0, 0) }
        
        let prices = priceHistory.map { $0.price }
        let high = prices.max() ?? 0
        let low = prices.min() ?? 0
        let average = prices.reduce(0, +) / Double(prices.count)
        
        let variance = prices.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(prices.count)
        let volatility = sqrt(variance) / average
        
        return (high, low, average, volatility)
    }
}

// Updated StatCard for better appearance
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// Supporting extensions
extension Double {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = self < 1 ? 6 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    var formattedChartPrice: String {
        if self >= 1000000 {
            return String(format: "$%.1fM", self/1000000)
        } else if self >= 1000 {
            return String(format: "$%.1fK", self/1000)
        } else if self >= 1 {
            return String(format: "$%.2f", self)
        } else {
            return String(format: "$%.6f", self)
        }
    }
}
// Supporting extensions
extension Double {

    
    func isApproximatelyEqual(to other: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(self - other) <= tolerance
    }
}

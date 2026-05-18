namespace DMCShop.Domain.Dtos;

/// <summary>
/// Fraud ring detayı — visualizer için. Pattern bazlı:
///   shared_device: bir cihaz, paylaşan müşteriler
///   shared_ip:     bir IP, üzerinde çalışan cihazlar, onları kullanan müşteriler
///   shared_card:   bir kart fingerprint, sahibi müşteriler
/// </summary>
public sealed record FraudRingDetail(
    string                      Pattern,
    string                      SignalLabel,        // "device:abc123…" veya "ip:192.0.2.150" veya "card:**XXXX…"
    string                      RiskLevel,
    IReadOnlyList<FraudCustomer> Customers,
    IReadOnlyList<FraudDevice>   Devices,           // shared_ip pattern'inde dolu
    int                          OrderCountTotal);

public sealed record FraudCustomer(
    int    CustomerId,
    string FullName,
    string City,
    int    OrderCount);

public sealed record FraudDevice(
    long   DeviceId,
    string FingerprintShort,
    string IpAddress);

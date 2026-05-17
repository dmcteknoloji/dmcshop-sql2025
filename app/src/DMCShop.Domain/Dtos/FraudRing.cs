namespace DMCShop.Domain.Dtos;

public sealed record FraudRing(
    string Pattern,        // 'shared_device', 'shared_ip', 'shared_card', 'cross_signal'
    string RiskLevel,      // 'HIGH', 'MEDIUM'
    int    CustomerCount,
    string CustomerList,   // STRING_AGG
    string Evidence);      // evidence path / explanation

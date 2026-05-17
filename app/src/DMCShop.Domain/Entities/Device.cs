namespace DMCShop.Domain.Entities;

public sealed class Device
{
    public long DeviceId { get; set; }
    public string Fingerprint { get; set; } = string.Empty;
    public string IpAddress { get; set; } = string.Empty;
    public string? UserAgent { get; set; }
    public DateTime FirstSeen { get; set; }
    public DateTime LastSeen { get; set; }
}

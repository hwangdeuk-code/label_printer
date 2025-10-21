// get_primary_ipv4.cpp
//       (MSVC) #pragma comment(lib, "iphlpapi.lib")

#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <string>
#include <vector>
#include <algorithm>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "iphlpapi.lib")

namespace {

bool IsBadIPv4(const std::string& ip) {
    if (ip.empty() || ip == "0.0.0.0" || ip == "255.255.255.255") return true;
    unsigned a,b,c,d;
    if (sscanf_s(ip.c_str(), "%u.%u.%u.%u", &a,&b,&c,&d) != 4) return true;
    if (a == 127) return true;               // loopback 127.0.0.0/8
    if (a == 169 && b == 254) return true;   // APIPA 169.254.0.0/16
    if (a >= 224 && a <= 239) return true;   // multicast 224.0.0.0/4
    return false;
}

// Filter for virtual/tunnel adapters by description/name
bool LooksVirtualOrTunnel(const IP_ADAPTER_ADDRESSES* a) {
    // IfType 기반 1차 필터
    if (a->IfType == IF_TYPE_TUNNEL) return true;              // 131
    if (a->IfType == IF_TYPE_SOFTWARE_LOOPBACK) return true;   // 24

    // TunnelType 기반 2차 필터
    if (a->TunnelType != TUNNEL_TYPE_NONE) return true;

    // 이름/설명 기반 3차 필터
    auto has = [](const wchar_t* w, const wchar_t* key) {
        if (!w || !key) return false;
        std::wstring ws(w);
        std::wstring kk(key);
        std::transform(ws.begin(), ws.end(), ws.begin(), ::towlower);
        std::transform(kk.begin(), kk.end(), kk.begin(), ::towlower);
        return ws.find(kk) != std::wstring::npos;
    };

    if (has(a->FriendlyName, L"hyper-v")      ||
        has(a->FriendlyName, L"vmware")       ||
        has(a->FriendlyName, L"virtualbox")   ||
        has(a->FriendlyName, L"tailscale")    ||
        has(a->FriendlyName, L"zerotier")     ||
        has(a->FriendlyName, L"docker")       ||
        has(a->FriendlyName, L"wsl")          ||
        has(a->FriendlyName, L"npCap")        ||
        has(a->Description,  L"hyper-v")      ||
        has(a->Description,  L"vmware")       ||
        has(a->Description,  L"virtualbox")   ||
        has(a->Description,  L"tailscale")    ||
        has(a->Description,  L"zerotier")     ||
        has(a->Description,  L"docker")       ||
        has(a->Description,  L"wsl")          ||
        has(a->Description,  L"npCap"))
        return true;

    return false;
}

} // namespace

// Returns the first IPv4 of the interface selected based on the default route (to a dummy external address like 1.1.1.1)
// Returns an empty string on failure.
std::string GetPrimaryIPv4()
{
    // 1) Initialize WSA
    WSADATA wsa{};
    if (WSAStartup(MAKEWORD(2,2), &wsa) != 0) {
        return {};
    }

    // 2) 외부 목적지(1.1.1.1)까지의 "최적 인터페이스" IfIndex 얻기
    DWORD ifIndex = 0;
    sockaddr_in dest{};
    dest.sin_family = AF_INET;
    inet_pton(AF_INET, "1.1.1.1", &dest.sin_addr);

    if (GetBestInterfaceEx(reinterpret_cast<sockaddr*>(&dest), &ifIndex) != NO_ERROR) {
        WSACleanup();
        return {};
    }

    // 3) List adapters, match IfIndex, check for Up status, optionally exclude virtual/tunnel, and get the first IPv4
    ULONG flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST |
                  GAA_FLAG_SKIP_DNS_SERVER | GAA_FLAG_INCLUDE_PREFIX;
    ULONG family = AF_INET;

    ULONG sz = 0;
    GetAdaptersAddresses(family, flags, nullptr, nullptr, &sz);
    if (sz == 0) { WSACleanup(); return {}; }

    std::vector<unsigned char> buf(sz);
    auto aa = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buf.data());
    if (GetAdaptersAddresses(family, flags, nullptr, aa, &sz) != NO_ERROR) {
        WSACleanup(); return {};
    }

    std::string ip;

    for (auto p = aa; p; p = p->Next) {
        // GetBestInterfaceEx returns an IPv4 IfIndex for an IPv4 destination
        if (p->IfIndex != ifIndex) continue;

        // Check operational status
        if (p->OperStatus != IfOperStatusUp) break;

        // Exclude virtual/tunnel/loopback (remove this line if not desired)
        if (LooksVirtualOrTunnel(p)) break;

        for (auto u = p->FirstUnicastAddress; u; u = u->Next) {
            if (!u->Address.lpSockaddr) continue;
            if (u->Address.lpSockaddr->sa_family != AF_INET) continue;
            auto sin = reinterpret_cast<const sockaddr_in*>(u->Address.lpSockaddr);
            char bufIp[INET_ADDRSTRLEN] = {};
            if (inet_ntop(AF_INET, &sin->sin_addr, bufIp, sizeof(bufIp))) {
                std::string candidate = bufIp;
                if (!IsBadIPv4(candidate)) {
                    ip = candidate;
                    break;
                }
            }
        }
        break; // Only look at this interface
    }

    WSACleanup();
    return ip;
}

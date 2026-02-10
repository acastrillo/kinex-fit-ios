"use client"

import Link from "next/link"
import { Button, buttonVariants } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent } from "@/components/ui/card"
import { cn } from "@/lib/utils"
import {
    Dumbbell,
    Zap,
    Target,
    TrendingUp,
    ArrowRight,
    CheckCircle2,
    Sparkles,
    Smartphone,
    BrainCircuit,
    Users
} from "lucide-react"

export default function LandingPage() {
    return (
        <div className="min-h-screen bg-[#0A0A0A] text-white overflow-x-hidden font-sans selection:bg-[#FF6B35] selection:text-white">

            {/* Navbar */}
            <nav className="fixed top-0 w-full z-50 border-b border-white/10 bg-[#0A0A0A]/80 backdrop-blur-md">
                <div className="container mx-auto px-6 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div className="bg-gradient-to-br from-[#FF6B35] to-[#FF9F2E] p-1.5 rounded-lg">
                            <Dumbbell className="h-5 w-5 text-white" />
                        </div>
                        <span className="text-xl font-bold tracking-tight">Kinex Fit</span>
                    </div>
                    <div className="hidden md:flex items-center gap-8 text-sm font-medium text-white/70">
                        <Link href="#features" className="hover:text-white transition-colors">Features</Link>
                        <Link href="#how-it-works" className="hover:text-white transition-colors">How it works</Link>
                        <Link href="#pricing" className="hover:text-white transition-colors">Pricing</Link>
                    </div>
                    <div className="flex items-center gap-4">
                        <Link href="/sign-in" className="text-sm font-medium text-white/70 hover:text-white hidden sm:block">
                            Log in
                        </Link>
                        <Link
                            href="/beta-signup"
                            className={cn(
                                buttonVariants(),
                                "bg-[#FF6B35] hover:bg-[#E55A2B] text-white border-none rounded-full px-6"
                            )}
                        >
                            Get Early Access
                        </Link>
                    </div>
                </div>
            </nav>

            {/* Hero Section */}
            <section className="relative pt-32 pb-20 lg:pt-48 lg:pb-32 overflow-hidden">
                {/* Background Effects */}
                <div className="absolute top-0 center text-white pointer-events-none w-full h-full z-0">
                    <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-[#FF6B35]/20 rounded-full blur-3xl mix-blend-screen animate-pulse" style={{ animationDuration: '4s' }} />
                    <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl mix-blend-screen" />
                </div>

                <div className="container relative mx-auto px-6 text-center z-10">
                    <Badge variant="outline" className="mb-6 py-1.5 px-4 rounded-full border-[#FF6B35]/30 bg-[#FF6B35]/10 text-[#FF6B35] hover:bg-[#FF6B35]/20 transition-colors uppercase tracking-widest text-xs font-semibold">
                        <Sparkles className="w-3 h-3 mr-2 inline-block" />
                        AI-Powered Fitness Revolution
                    </Badge>

                    <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6 leading-[1.1]">
                        <span className="block text-white">Your Personal Coach.</span>
                        <span className="bg-gradient-to-r from-[#FF6B35] to-[#FF9F2E] bg-clip-text text-transparent">
                            Available 24/7.
                        </span>
                    </h1>

                    <p className="max-w-2xl mx-auto text-lg md:text-xl text-zinc-400 mb-10 leading-relaxed">
                        Stop guessing what to do in the gym. Kinex Fit builds dynamic, personalized fitness plans that adapt to your progress, schedule, and goals—automatically.
                    </p>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                        <Link
                            href="/beta-signup"
                            className={cn(
                                buttonVariants({ size: "lg" }),
                                "bg-[#FF6B35] hover:bg-[#E55A2B] text-white rounded-full px-8 h-12 text-base shadow-[0_0_20px_rgba(255,107,53,0.3)] hover:shadow-[0_0_30px_rgba(255,107,53,0.5)] transition-all duration-300 flex items-center"
                            )}
                        >
                            Start Training Free <ArrowRight className="ml-2 h-4 w-4" />
                        </Link>
                        <Link
                            href="#how-it-works"
                            className={cn(
                                buttonVariants({ variant: "outline", size: "lg" }),
                                "border-zinc-800 text-zinc-300 hover:bg-zinc-900 hover:text-white rounded-full px-8 h-12 text-base backdrop-blur-sm bg-black/30"
                            )}
                        >
                            View Demo
                        </Link>
                    </div>

                    {/* Stats/Social Proof */}
                    <div className="mt-20 pt-10 border-t border-white/5 grid grid-cols-2 md:grid-cols-4 gap-8">
                        {[
                            { label: "Active Users", value: "2,000+" },
                            { label: "Workouts Generated", value: "50k+" },
                            { label: "Exercises", value: "800+" },
                            { label: "App Store Rating", value: "4.9/5" },
                        ].map((stat, i) => (
                            <div key={i}>
                                <div className="text-3xl font-bold text-white mb-1">{stat.value}</div>
                                <div className="text-sm text-zinc-500 uppercase tracking-wider font-medium">{stat.label}</div>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Features Grid */}
            <section id="features" className="py-24 bg-zinc-950/50 relative">
                <div className="container mx-auto px-6">
                    <div className="text-center max-w-3xl mx-auto mb-20">
                        <h2 className="text-3xl md:text-5xl font-bold mb-6">Built for <span className="text-[#FF6B35]">Peak Performance</span></h2>
                        <p className="text-zinc-400 text-lg">
                            Everything you need to crush your fitness goals, powered by advanced AI and biological insights.
                        </p>
                    </div>

                    <div className="grid md:grid-cols-3 gap-6">
                        <Card className="bg-zinc-900/50 border-zinc-800 hover:border-[#FF6B35]/50 transition-colors group">
                            <CardContent className="p-8">
                                <div className="w-12 h-12 rounded-xl bg-[#FF6B35]/10 flex items-center justify-center mb-6 group-hover:bg-[#FF6B35] transition-colors duration-300">
                                    <BrainCircuit className="w-6 h-6 text-[#FF6B35] group-hover:text-white" />
                                </div>
                                <h3 className="text-xl font-bold mb-3 text-white">Smart Adaptation</h3>
                                <p className="text-zinc-400 leading-relaxed">
                                    Our AI analyzes every rep and set to adjust your next workout. Too easy? We ramp it up. Too hard? We dial it back.
                                </p>
                            </CardContent>
                        </Card>

                        <Card className="bg-zinc-900/50 border-zinc-800 hover:border-[#FF6B35]/50 transition-colors group">
                            <CardContent className="p-8">
                                <div className="w-12 h-12 rounded-xl bg-[#FF6B35]/10 flex items-center justify-center mb-6 group-hover:bg-[#FF6B35] transition-colors duration-300">
                                    <Target className="w-6 h-6 text-[#FF6B35] group-hover:text-white" />
                                </div>
                                <h3 className="text-xl font-bold mb-3 text-white">Goal-Oriented Plans</h3>
                                <p className="text-zinc-400 leading-relaxed">
                                    Whether it's hypertrophy, strength, or endurance, get a plan backed by sports science, not bro-science.
                                </p>
                            </CardContent>
                        </Card>

                        <Card className="bg-zinc-900/50 border-zinc-800 hover:border-[#FF6B35]/50 transition-colors group">
                            <CardContent className="p-8">
                                <div className="w-12 h-12 rounded-xl bg-[#FF6B35]/10 flex items-center justify-center mb-6 group-hover:bg-[#FF6B35] transition-colors duration-300">
                                    <TrendingUp className="w-6 h-6 text-[#FF6B35] group-hover:text-white" />
                                </div>
                                <h3 className="text-xl font-bold mb-3 text-white">Visual Progress</h3>
                                <p className="text-zinc-400 leading-relaxed">
                                    See your strength grow with detailed analytics. Track PRs, volume, and consistency in one beautiful dashboard.
                                </p>
                            </CardContent>
                        </Card>
                    </div>
                </div>
            </section>

            {/* Bento Grid Section */}
            <section className="py-24">
                <div className="container mx-auto px-6">
                    <div className="grid md:grid-cols-2 gap-8 items-center">
                        <div className="space-y-8">
                            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-zinc-900 border border-zinc-800 text-sm text-zinc-300">
                                <Smartphone className="w-4 h-4" />
                                <span>Mobile First Experience</span>
                            </div>
                            <h2 className="text-4xl md:text-5xl font-bold leading-tight">
                                Your entire gym log.<br />
                                <span className="text-zinc-500">Reimagined.</span>
                            </h2>
                            <p className="text-lg text-zinc-400">
                                Forget the notebook. Kinex Fit provides a frictionless logging experience that stays out of your way so you can focus on lifting.
                            </p>

                            <div className="space-y-4">
                                {[
                                    "One-tap set logging",
                                    "Rest timer with notifications",
                                    "Previous weight history lookup",
                                    "RPE and Notes tracking"
                                ].map((item, i) => (
                                    <div key={i} className="flex items-center gap-3">
                                        <CheckCircle2 className="w-5 h-5 text-[#FF6B35]" />
                                        <span className="text-zinc-300">{item}</span>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="relative">
                            {/* Abstract App UI Representation */}
                            <div className="relative z-10 bg-zinc-900 border border-zinc-800 rounded-3xl p-6 shadow-2xl rotate-3 hover:rotate-0 transition-transform duration-500">
                                <div className="flex items-center justify-between mb-8">
                                    <div className="space-y-1">
                                        <div className="text-zinc-400 text-xs uppercase tracking-wider">Today's Focus</div>
                                        <div className="text-2xl font-bold">Push Hypertrophy</div>
                                    </div>
                                    <div className="bg-[#FF6B35] text-xs font-bold px-2 py-1 rounded text-white">45m</div>
                                </div>

                                <div className="space-y-4">
                                    {[1, 2, 3].map((_, i) => (
                                        <div key={i} className="bg-zinc-950/50 rounded-xl p-4 flex items-center justify-between">
                                            <div className="flex items-center gap-4">
                                                <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                                                    <Dumbbell className="w-5 h-5 text-zinc-400" />
                                                </div>
                                                <div>
                                                    <div className="font-semibold text-sm">Incline Bench Press</div>
                                                    <div className="text-xs text-zinc-500">3 sets • 8-12 reps</div>
                                                </div>
                                            </div>
                                            <div className="text-[#FF6B35] font-mono text-sm">Logged</div>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Decorative elements */}
                            <div className="absolute top-10 -right-10 w-full h-full border-2 border-[#FF6B35]/20 rounded-3xl -z-10 rotate-6"></div>
                            <div className="absolute -bottom-10 -left-10 w-40 h-40 bg-[#FF6B35]/20 blur-3xl rounded-full -z-10"></div>
                        </div>
                    </div>
                </div>
            </section>

            {/* CTA Section */}
            <section className="py-24 px-6">
                <div className="container mx-auto">
                    <div className="relative bg-gradient-to-br from-[#FF6B35] to-[#E55A2B] rounded-3xl p-12 md:p-24 text-center overflow-hidden">
                        {/* Background Pattern */}
                        <div className="absolute inset-0 opacity-10" style={{ backgroundImage: 'radial-gradient(circle at 2px 2px, white 1px, transparent 0)', backgroundSize: '40px 40px' }}></div>

                        <div className="relative z-10 max-w-3xl mx-auto">
                            <h2 className="text-4xl md:text-5xl font-bold text-white mb-8">Ready to transform your physique?</h2>
                            <p className="text-white/80 text-xl mb-10">
                                Join thousands of athletes who trust Kinex Fit to program their perfect workout.
                            </p>
                            <div className="flex flex-col sm:flex-row gap-4 justify-center">
                                <Link
                                    href="/beta-signup"
                                    className="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full text-lg font-bold transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 bg-white text-[#FF6B35] hover:bg-white/90 hover:text-[#E55A2B] px-10 h-14 shadow-lg"
                                >
                                    Get Started for Free
                                </Link>
                            </div>
                            <p className="mt-8 text-sm text-white/60">
                                No credit card required. Cancel anytime.
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Footer */}
            <footer className="border-t border-zinc-900 bg-[#050505] py-12 text-center md:text-left">
                <div className="container mx-auto px-6">
                    <div className="flex flex-col md:flex-row justify-between items-center gap-8">
                        <div className="flex items-center gap-2">
                            <Dumbbell className="h-6 w-6 text-[#FF6B35]" />
                            <span className="text-xl font-bold text-white">Kinex Fit</span>
                        </div>
                        <div className="text-zinc-500 text-sm">
                            &copy; {new Date().getFullYear()} Kinex Fit. All rights reserved.
                        </div>
                        <div className="flex gap-6">
                            {[
                                { icon: Users, href: "#" },
                                { icon: Smartphone, href: "#" },
                            ].map((item, i) => (
                                <Link key={i} href={item.href} className="text-zinc-500 hover:text-[#FF6B35] transition-colors">
                                    <item.icon className="w-5 h-5" />
                                </Link>
                            ))}
                        </div>
                    </div>
                </div>
            </footer>
        </div>
    )
}

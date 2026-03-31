import { Header } from "@/components/header";
import { cn } from "@/lib/utils";
import { FullWidthDivider } from "@/components/ui/landing/full-width-divider";
import { ArrowRightIcon, RocketIcon, BriefcaseIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DecorIcon } from "@/components/ui/landing/decor-icon";
import { AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { GridFiller } from "@/components/ui/landing/grid-filler";
import { GridPattern } from "@/components/ui/landing/grid-pattern";
import { Avatar } from "@/components/ui/avatar";
import Link from "next/link";
import { Footer } from "@/components/footer";
import { HeaderWrapper } from "@/components/header-wrapper";
import { FeatureSection } from "@/components/feature-section";
import { TestimonialsSection } from "@/components/testimonials-section";


export function HeroSection() {
  return (
    <section className="w-full">
      {/* Top Shades */}
      <div
        aria-hidden="true"
        className="absolute inset-0 isolate hidden overflow-hidden contain-strict lg:block"
      >
        <div className="absolute inset-0 -top-14 isolate -z-10 bg-[radial-gradient(35%_80%_at_49%_0%,--theme(--color-foreground/.08),transparent)] contain-strict" />
      </div>

      {/* X Bold Faded Borders */}
      <div
        aria-hidden="true"
        className="absolute inset-0 mx-auto hidden min-h-screen w-full lg:block"
      >
        <div className="mask-y-from-80% mask-y-to-100% absolute inset-y-0 left-0 z-10 h-full w-px bg-foreground/15" />
        <div className="mask-y-from-80% mask-y-to-100% absolute inset-y-0 right-0 z-10 h-full w-px bg-foreground/15" />
      </div>

      {/* main content */}

      <div className="relative flex flex-col items-center justify-center gap-5 pt-32 pb-30">
        {/* X Content Faded Borders */}
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-1 size-full overflow-hidden"
        >
          <div className="absolute inset-y-0 left-4 w-px bg-linear-to-b from-transparent via-border to-border md:left-8" />
          <div className="absolute inset-y-0 right-4 w-px bg-linear-to-b from-transparent via-border to-border md:right-8" />
          <div className="absolute inset-y-0 left-8 w-px bg-linear-to-b from-transparent via-border/50 to-border/50 md:left-12" />
          <div className="absolute inset-y-0 right-8 w-px bg-linear-to-b from-transparent via-border/50 to-border/50 md:right-12" />
        </div>

        <a
          className={cn(
            "group mx-auto flex w-fit items-center gap-3 rounded-full border bg-card px-3 py-1 shadow",
            "fade-in slide-in-from-bottom-10 animate-in fill-mode-backwards transition-all delay-500 duration-500 ease-out"
          )}
          href="#link"
        >
          <RocketIcon className="size-3 text-muted-foreground" />
          <span className="text-xs">1,000+ mock tests attempted</span>
          <span className="block h-5 border-l" />

          <ArrowRightIcon className="size-3 duration-150 ease-out group-hover:translate-x-1" />
        </a>

        <h1
          className={cn(
            "fade-in slide-in-from-bottom-10 animate-in text-balance fill-mode-backwards text-center text-4xl tracking-tight delay-100 duration-500 ease-out md:text-5xl lg:text-6xl",
            "text-shadow-[0_0px_50px_theme(--color-foreground/.2)]"
          )}
        >
          The Gap Between You <br /> and Your Goal? Let's Close It.
        </h1>

        <p className="fade-in slide-in-from-bottom-10 mx-auto max-w-md animate-in fill-mode-backwards text-center text-base text-foreground/80 tracking-wider delay-200 duration-500 ease-out sm:text-lg md:text-xl">
          Practice with mock tests, track your progress, <br /> and crush your goals with Placetrix.
        </p>

        <div className="fade-in slide-in-from-bottom-10 flex animate-in flex-row flex-wrap items-center justify-center gap-3 fill-mode-backwards pt-2 delay-300 duration-500 ease-out">
          <Link href="/auth/sign-up">
            <Button className="rounded-full" size="lg">
              Start Practicing
              <ArrowRightIcon data-icon="inline-end" />
            </Button>
          </Link>
          <Link href="/auth/sign-in">
            <Button className="rounded-full" size="lg" variant="secondary">
              <BriefcaseIcon data-icon="inline-start" />
              I'm a Recruiter
            </Button>
          </Link>
        </div>
      </div>
    </section>
  );
}




export default function LandingPage() {
  return (
    <div className="relative flex min-h-screen flex-col overflow-hidden supports-[overflow:clip]:overflow-clip">
      <HeaderWrapper />
      <main
        className={cn(
          "relative mx-auto w-full grow",
          // X Borders — hidden on very small screens to avoid clipping content
          "sm:before:absolute sm:before:-inset-y-14 sm:before:-left-px sm:before:w-px sm:before:bg-border",
          "sm:after:absolute sm:after:-inset-y-14 sm:after:-right-px sm:after:w-px sm:after:bg-border"
        )}
      >
        <HeroSection />
        <FeatureSection />
        <TestimonialsSection />
        <Footer />
      </main>
    </div>
  );
}

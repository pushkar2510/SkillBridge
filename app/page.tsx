import { Header } from "@/components/header";
import { cn } from "@/lib/utils";
import { FullWidthDivider } from "@/components/ui/landing/full-width-divider";
import { ArrowRightIcon, RocketIcon, GraduationCapIcon } from "lucide-react";
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
							<GraduationCapIcon data-icon="inline-start" />
							I'm an Institute
						</Button>
					</Link>
				</div>
			</div>
		</section>
	);
}


function TestimonialsSection() {
  return (
    <div className="mx-auto max-w-5xl space-y-6 pt-8 pb-0 sm:space-y-8 sm:pt-6 md:pt-14">
      <div className="flex flex-col gap-1.5 px-4 sm:gap-2 md:px-6">
        <h1 className="text-balance text-center font-semibold text-2xl tracking-wide sm:text-3xl md:text-4xl xl:font-bold">
          Real Students, Real Results
        </h1>
        <p className="text-muted-foreground text-center text-sm md:text-base lg:text-lg">
          Trusted by students and educators across India to prepare for
          competitive exams with confidence.
        </p>
      </div>
      <div className="relative grid grid-cols-1 gap-px bg-border sm:grid-cols-2 lg:grid-cols-3">
        <FullWidthDivider position="top" />
        {testimonials.map((testimonial) => (
          <TestimonialsCard key={testimonial.name} testimonial={testimonial} />
        ))}
        <GridFiller
          className="bg-background"
          lgColumns={3}
          smColumns={2}
          totalItems={testimonials.length}
        />
        <FullWidthDivider position="bottom" />
      </div>
    </div>
  );
}


type Testimonial = {
  name: string;
  role: string;
  image: string;
  company?: string;
  quote: string;
};


const testimonials: Testimonial[] = [
  {
    quote:
      "The sectional tests helped me specifically improve logical reasoning, which was heavily asked in my internship screening round.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Kunal Shah",
    name: "Kunal Shah",
    role: "Data Analyst Intern",
    company: "Wipro",
  },
  {
    quote:
      "The timed mock tests on Placetrix exposed my weak spots fast. Within weeks, my aptitude accuracy jumped from 60% to 85%. That made a real difference in my placement rounds.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Aditya Patil",
    name: "Aditya Patil",
    role: "Software Engineer",
    company: "Infosys",
  },
  {
    quote:
      "Placetrix analytics showed me exactly where I was failing. I stopped wasting time on random prep and focused only on high-impact topics. Cleared my first attempt.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Neha Verma",
    name: "Neha Verma",
    role: "Analyst",
    company: "Deloitte",
  },
  {
    quote:
      "Consistency was my biggest problem. The daily practice streaks on Placetrix forced discipline, and that’s what ultimately got me placed.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Rohit Sharma",
    name: "Rohit Sharma",
    role: "Associate Engineer",
    company: "Capgemini",
  },

  // Internships
  {
    quote:
      "Before Placetrix, I struggled with basic aptitude. The structured practice helped me crack my first internship test confidently.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Pooja Nair",
    name: "Pooja Nair",
    role: "Software Intern",
    company: "TCS",
  },
 
  {
    quote:
      "I used Placetrix for just 3 weeks before my internship drive. The speed improvement alone helped me clear the cutoff easily.",
    image: "https://api.dicebear.com/9.x/glass/svg?seed=Anjali Gupta",
    name: "Anjali Gupta",
    role: "Backend Developer Intern",
    company: "Cognizant",
  },
];


function TestimonialsCard({
  testimonial,
  className,
  ...props
}: React.ComponentProps<"figure"> & {
  testimonial: Testimonial;
}) {
  const { quote, company, image, name, role } = testimonial;
  return (
    <figure
      className={cn(
        "relative grid grid-cols-[auto_1fr] gap-x-3 overflow-hidden bg-background p-3 sm:p-4",
        className
      )}
      {...props}
    >
      <div className="mask-[radial-gradient(farthest-side_at_top,white,transparent)] pointer-events-none absolute top-0 left-1/2 -mt-2 -ml-20 size-full">
        <GridPattern
          className="absolute inset-0 size-full stroke-border"
          height={25}
          width={25}
          x={-12}
          y={4}
        />
      </div>


      <Avatar className="size-8 rounded-full">
        <AvatarImage alt={`${name}'s profile picture`} src={image} className="object-cover" />
        <AvatarFallback>{name.charAt(0)}</AvatarFallback>
      </Avatar>
      <div>
        <figcaption className="-mt-0.5 -space-y-0.5">
          <cite className="text-sm not-italic md:text-base">{name}</cite>
          <span className="block font-light text-[11px] text-muted-foreground tracking-tight">
            {role}
            {company && `, ${company}`}
          </span>
        </figcaption>
        <blockquote className="mt-2 sm:mt-3">
          <p className="text-foreground/80 text-sm tracking-wide leading-relaxed">{quote}</p>
        </blockquote>
      </div>
    </figure>
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

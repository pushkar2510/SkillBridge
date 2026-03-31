"use client"

import * as React from "react"
import Link from "next/link"
import {
  updateOpportunityStatusAction,
  updateApplicationStatusAction,
  bulkUpdateApplicationStatusAction,
} from "../actions"
import type { Opportunity, RecruiterApplication, ApplicationStatus } from "../_types"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { toast } from "sonner"
import { motion } from "motion/react"
import {
  ArrowLeft,
  Briefcase,
  Users,
  MapPin,
  CalendarClock,
  PenLine,
  CheckCircle2,
  ChevronsRight,
  Filter,
  X,
} from "lucide-react"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"

import { KanbanBoard, COLUMNS } from "./KanbanBoard"

function formatDateTime(dt?: string): string {
  if (!dt) return "—"
  return new Date(dt).toLocaleString("en-US", { dateStyle: "medium" })
}

// ─── Status Filter Bar ────────────────────────────────────────────────────────
function StatusFilterBar({
  activeFilters,
  onToggle,
  onClear,
  counts,
}: {
  activeFilters: Set<ApplicationStatus>
  onToggle: (status: ApplicationStatus) => void
  onClear: () => void
  counts: Record<ApplicationStatus, number>
}) {
  const hasActive = activeFilters.size > 0 && activeFilters.size < COLUMNS.length

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
        <Filter className="h-3.5 w-3.5" />
        Filter
      </div>
      {COLUMNS.map((col) => {
        const isActive = activeFilters.has(col.id)
        const count = counts[col.id] ?? 0
        return (
          <button
            key={col.id}
            onClick={() => onToggle(col.id)}
            className={`
              flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium
              transition-all duration-150 select-none
              ${isActive
                ? `${col.pillClass} border-transparent shadow-sm`
                : "border-border bg-transparent text-muted-foreground hover:border-primary/30 hover:text-foreground"
              }
            `}
          >
            <span className={`h-1.5 w-1.5 rounded-full ${col.dotColor}`} />
            {col.label}
            {count > 0 && (
              <span className={`text-[10px] font-bold rounded-full min-w-4 h-4 flex items-center justify-center px-1 ${isActive ? "bg-white/20" : "bg-muted"}`}>
                {count}
              </span>
            )}
          </button>
        )
      })}
      {hasActive && (
        <button
          onClick={onClear}
          className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          <X className="h-3 w-3" /> Clear
        </button>
      )}
    </div>
  )
}

// ─── Main Client Component ────────────────────────────────────────────────────
export function OpportunityDetailClient({
  opportunity,
  applications: initialApplications,
}: {
  opportunity: Opportunity
  applications: RecruiterApplication[]
}) {
  const [isUpdating, setIsUpdating] = React.useState(false)
  const [applications, setApplications] = React.useState<RecruiterApplication[]>(initialApplications)

  // All statuses active by default = "show all"
  const [activeFilters, setActiveFilters] = React.useState<Set<ApplicationStatus>>(
    new Set(COLUMNS.map((c) => c.id))
  )

  // Sync if server rerenders
  React.useEffect(() => {
    setApplications(initialApplications)
  }, [initialApplications])

  // ── Counts per status (used by filter bar + stats) ───────────────────────
  const counts = React.useMemo(() => {
    const c = {} as Record<ApplicationStatus, number>
    for (const col of COLUMNS) c[col.id] = 0
    for (const app of applications) {
      // "applied" maps to the "pending" column visually
      const key = app.status === "applied" ? "pending" : app.status
      if (key in c) c[key as ApplicationStatus]++
    }
    return c
  }, [applications])

  // ── Filtered applications fed to the Kanban ──────────────────────────────
  // "Show all" when all filters are on, or when none are explicitly unchecked.
  const allActive = activeFilters.size === COLUMNS.length
  const filteredApplications = allActive
    ? applications
    : applications.filter((app) => {
        const colId = app.status === "applied" ? "pending" : app.status
        return activeFilters.has(colId as ApplicationStatus)
      })

  // ── Toggle a single filter chip ──────────────────────────────────────────
  const toggleFilter = (status: ApplicationStatus) => {
    setActiveFilters((prev) => {
      const next = new Set(prev)
      if (next.has(status)) {
        // Don't allow deselecting everything
        if (next.size === 1) return prev
        next.delete(status)
      } else {
        next.add(status)
      }
      return next
    })
  }

  const clearFilters = () =>
    setActiveFilters(new Set(COLUMNS.map((c) => c.id)))

  // ── Single application status update (from Kanban) ───────────────────────
  const handleUpdateAppStatus = async (appId: string, newStatus: ApplicationStatus) => {
    const previousState = [...applications]
    setApplications((apps) =>
      apps.map((app) => (app.id === appId ? { ...app, status: newStatus } : app))
    )
    try {
      setIsUpdating(true)
      await updateApplicationStatusAction(appId, newStatus)
      toast.success(`Moved to ${COLUMNS.find((c) => c.id === newStatus)?.label ?? newStatus}`)
    } catch (error) {
      setApplications(previousState)
      toast.error(error instanceof Error ? error.message : "Failed to update status")
    } finally {
      setIsUpdating(false)
    }
  }

  // ── Bulk: move ALL pending applicants → applied ───────────────────────────
  const pendingCount = applications.filter(
    (a) => a.status === "pending" || a.status === "applied"
  ).length

  const handleMoveAllToApplied = async () => {
    if (pendingCount === 0) return
    const previousState = [...applications]

    // Optimistic: flip every pending → applied
    setApplications((apps) =>
      apps.map((app) =>
        app.status === "pending" ? { ...app, status: "applied" as ApplicationStatus } : app
      )
    )

    try {
      setIsUpdating(true)
      const { updated } = await bulkUpdateApplicationStatusAction(
        opportunity.id,
        ["pending"],
        "applied"
      )
      toast.success(`${updated} applicant${updated !== 1 ? "s" : ""} moved to Applied`)
    } catch (error) {
      setApplications(previousState)
      toast.error(error instanceof Error ? error.message : "Bulk update failed")
    } finally {
      setIsUpdating(false)
    }
  }

  const handleCloseJob = async () => {
    try {
      setIsUpdating(true)
      await updateOpportunityStatusAction(opportunity.id, "archived")
      toast.success("Job posting closed successfully")
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to close posting")
    } finally {
      setIsUpdating(false)
    }
  }

  return (
    <div className="min-h-screen w-full pb-12">
      {/* ── Page Header ───────────────────────────────────────────────────── */}
      <div className="px-4 pt-6 pb-2 md:px-8 max-w-6xl mx-auto">
        <Button variant="ghost" size="sm" asChild className="mb-4 -ml-2 text-muted-foreground">
          <Link href="/~/postings">
            <ArrowLeft className="h-4 w-4 mr-1.5" /> Back to Postings
          </Link>
        </Button>
        <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
          <div className="space-y-1">
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold tracking-tight">{opportunity.title}</h1>
              <Badge variant={opportunity.status === "published" ? "default" : "secondary"}>
                {opportunity.status}
              </Badge>
            </div>
            <div className="flex items-center gap-4 text-sm text-muted-foreground">
              <span className="flex items-center gap-1.5">
                <MapPin className="h-4 w-4" />
                {opportunity.is_remote ? "Remote" : opportunity.location || "Location not set"}
              </span>
              <span className="flex items-center gap-1.5">
                <CalendarClock className="h-4 w-4" />
                Deadline: {formatDateTime(opportunity.application_deadline)}
              </span>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Button variant="outline" size="sm" asChild>
              <Link href={`/~/postings/${opportunity.id}/edit`}>
                <PenLine className="h-4 w-4 mr-1.5" /> Edit
              </Link>
            </Button>
            {opportunity.status !== "archived" && (
              <Button
                variant="destructive"
                size="sm"
                onClick={handleCloseJob}
                disabled={isUpdating}
              >
                Close Job
              </Button>
            )}
          </div>
        </div>
      </div>

      <div className="px-4 py-8 md:px-8 max-w-6xl mx-auto space-y-8">
        {/* ── Stats ─────────────────────────────────────────────────────── */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-muted/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Total Applicants</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold flex items-center gap-2">
                <Users className="h-6 w-6 text-emerald-500" />
                {applications.length}
              </div>
            </CardContent>
          </Card>
          <Card className="bg-muted/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Shortlisted</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold flex items-center gap-2">
                <CheckCircle2 className="h-6 w-6 text-blue-500" />
                {applications.filter((a) => a.status === "shortlisted").length}
              </div>
            </CardContent>
          </Card>
          <Card className="bg-muted/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Hired</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold flex items-center gap-2">
                <Briefcase className="h-6 w-6 text-purple-500" />
                {applications.filter((a) => a.status === "hired").length}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* ── Kanban Section ────────────────────────────────────────────── */}
        <div className="space-y-4">
          {/* Section title row */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-semibold tracking-tight">Applicants ATS Board</h2>
              <p className="text-sm text-muted-foreground">
                Drag and drop candidates to update their status.
              </p>
            </div>

            {/* Bulk action: Move All to Applied */}
            {pendingCount > 0 && (
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <motion.div
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.25 }}
                  >
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={isUpdating}
                      className="gap-1.5 border-slate-300 dark:border-slate-700 hover:border-primary/50 hover:bg-primary/5 transition-all"
                    >
                      <ChevronsRight className="h-4 w-4 text-primary" />
                      Move all to Applied
                      <span className="ml-1 rounded-full bg-slate-100 dark:bg-slate-800 text-[10px] font-bold px-1.5 py-0.5 min-w-5 text-center">
                        {pendingCount}
                      </span>
                    </Button>
                  </motion.div>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Move all pending applicants to Applied?</AlertDialogTitle>
                    <AlertDialogDescription>
                      This will move <strong>{pendingCount}</strong> applicant{pendingCount !== 1 ? "s" : ""} currently
                      in the <em>Applied</em> column from &quot;pending&quot; status to &quot;applied&quot; status in
                      the database. This action can be undone by moving them back manually.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction onClick={handleMoveAllToApplied}>
                      Yes, move {pendingCount} applicant{pendingCount !== 1 ? "s" : ""}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            )}
          </div>

          {/* ── Status Filter Bar ──────────────────────────────────────── */}
          <div className="flex items-center gap-3 flex-wrap rounded-xl border bg-muted/30 px-4 py-2.5">
            <StatusFilterBar
              activeFilters={activeFilters}
              onToggle={toggleFilter}
              onClear={clearFilters}
              counts={counts}
            />
            {!allActive && (
              <span className="ml-auto text-xs text-muted-foreground">
                Showing{" "}
                <strong>{filteredApplications.length}</strong> of{" "}
                {applications.length} applicants
              </span>
            )}
          </div>

          {/* ── Kanban Board ───────────────────────────────────────────── */}
          <KanbanBoard
            applications={filteredApplications}
            onStatusChange={handleUpdateAppStatus}
            isUpdating={isUpdating}
          />
        </div>
      </div>
    </div>
  )
}

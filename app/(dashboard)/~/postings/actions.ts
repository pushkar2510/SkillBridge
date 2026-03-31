"use server"

import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import type { ApplicationStatus, OpportunityStatus } from "./_types"

export async function updateOpportunityStatusAction(opportunityId: string, status: OpportunityStatus) {
  const supabase = await createClient()
  const { error } = await supabase
    .from("opportunities")
    .update({ status })
    .eq("id", opportunityId)

  if (error) throw new Error(error.message)
  revalidatePath("/~/postings")
  revalidatePath(`/~/postings/${opportunityId}`)
}

export async function updateApplicationStatusAction(applicationId: string, status: ApplicationStatus) {
  // Guard: ensure only valid DB-allowed statuses are ever written
  const VALID = ["pending", "applied", "reviewing", "shortlisted", "rejected", "hired"] as const
  if (!(VALID as readonly string[]).includes(status)) {
    throw new Error(`Invalid application status: "${status}"`)
  }

  const supabase = await createClient()
  const { error, data: updatedApp } = await supabase
    .from("applications")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", applicationId)
    .select("opportunity_id")
    .single()

  if (error) throw new Error(error.message)
  
  if (updatedApp?.opportunity_id) {
    revalidatePath(`/~/postings/${updatedApp.opportunity_id}`)
  }
}

/**
 * Bulk move ALL applicants in a given opportunity from one or more source statuses
 * to a target status. Used for "Move all to Applied" flow.
 */
export async function bulkUpdateApplicationStatusAction(
  opportunityId: string,
  fromStatuses: ApplicationStatus[],
  toStatus: ApplicationStatus
) {
  const VALID = ["pending", "applied", "reviewing", "shortlisted", "rejected", "hired"] as const
  if (!(VALID as readonly string[]).includes(toStatus)) {
    throw new Error(`Invalid target status: "${toStatus}"`)
  }

  const supabase = await createClient()
  const { error, count } = await supabase
    .from("applications")
    .update({ status: toStatus, updated_at: new Date().toISOString() })
    .eq("opportunity_id", opportunityId)
    .in("status", fromStatuses)

  if (error) throw new Error(error.message)

  revalidatePath(`/~/postings/${opportunityId}`)
  return { updated: count ?? 0 }
}


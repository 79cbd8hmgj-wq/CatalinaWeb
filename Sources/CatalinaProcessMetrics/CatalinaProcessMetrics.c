#include "CatalinaProcessMetrics.h"

#include <libproc.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/proc_info.h>
#include <sys/types.h>

#define CW_STATUS_OK 0
#define CW_STATUS_INVALID_ARGUMENT 1
#define CW_STATUS_ROOT_UNAVAILABLE 2
#define CW_STATUS_PID_LIST_UNAVAILABLE 3
#define CW_STATUS_ALLOCATION_FAILED 4

typedef struct {
    pid_t pid;
    pid_t ppid;
    bool descendant;
} CWProcessRelationship;

static bool cw_read_resident_bytes(pid_t pid, uint64_t *resident_bytes) {
    struct proc_taskinfo task_info;
    memset(&task_info, 0, sizeof(task_info));

    int result = proc_pidinfo(
        pid,
        PROC_PIDTASKINFO,
        0,
        &task_info,
        (int)sizeof(task_info)
    );
    if (result != (int)sizeof(task_info)) {
        return false;
    }

    *resident_bytes = task_info.pti_resident_size;
    return true;
}

static bool cw_read_parent_pid(pid_t pid, pid_t *parent_pid) {
    struct proc_bsdinfo bsd_info;
    memset(&bsd_info, 0, sizeof(bsd_info));

    int result = proc_pidinfo(
        pid,
        PROC_PIDTBSDINFO,
        0,
        &bsd_info,
        (int)sizeof(bsd_info)
    );
    if (result != (int)sizeof(bsd_info)) {
        return false;
    }

    *parent_pid = (pid_t)bsd_info.pbi_ppid;
    return true;
}

static bool cw_pid_is_marked_descendant(
    pid_t pid,
    const CWProcessRelationship *relationships,
    int relationship_count
) {
    for (int index = 0; index < relationship_count; index++) {
        if (relationships[index].pid == pid) {
            return relationships[index].descendant;
        }
    }
    return false;
}

int32_t cw_read_process_family_metrics(int32_t root_pid, CWProcessFamilyMetrics *out_metrics) {
    if (root_pid <= 0 || out_metrics == NULL) {
        return CW_STATUS_INVALID_ARGUMENT;
    }

    memset(out_metrics, 0, sizeof(*out_metrics));

    uint64_t root_resident_bytes = 0;
    if (!cw_read_resident_bytes((pid_t)root_pid, &root_resident_bytes)) {
        out_metrics->status = CW_STATUS_ROOT_UNAVAILABLE;
        return CW_STATUS_ROOT_UNAVAILABLE;
    }
    out_metrics->root_resident_bytes = root_resident_bytes;

    int estimated_pid_count = proc_listallpids(NULL, 0);
    if (estimated_pid_count <= 0) {
        out_metrics->status = CW_STATUS_PID_LIST_UNAVAILABLE;
        return CW_STATUS_PID_LIST_UNAVAILABLE;
    }

    int capacity = estimated_pid_count + 64;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    CWProcessRelationship *relationships = calloc(
        (size_t)capacity,
        sizeof(CWProcessRelationship)
    );
    if (pids == NULL || relationships == NULL) {
        free(pids);
        free(relationships);
        out_metrics->status = CW_STATUS_ALLOCATION_FAILED;
        return CW_STATUS_ALLOCATION_FAILED;
    }

    int pid_count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (pid_count <= 0) {
        free(pids);
        free(relationships);
        out_metrics->status = CW_STATUS_PID_LIST_UNAVAILABLE;
        return CW_STATUS_PID_LIST_UNAVAILABLE;
    }
    if (pid_count > capacity) {
        pid_count = capacity;
    }

    int relationship_count = 0;
    for (int index = 0; index < pid_count; index++) {
        pid_t pid = pids[index];
        if (pid <= 0 || pid == (pid_t)root_pid) {
            continue;
        }

        pid_t parent_pid = 0;
        if (!cw_read_parent_pid(pid, &parent_pid)) {
            continue;
        }

        relationships[relationship_count].pid = pid;
        relationships[relationship_count].ppid = parent_pid;
        relationships[relationship_count].descendant = false;
        relationship_count++;
    }

    bool changed = true;
    while (changed) {
        changed = false;
        for (int index = 0; index < relationship_count; index++) {
            if (relationships[index].descendant) {
                continue;
            }

            pid_t parent_pid = relationships[index].ppid;
            if (
                parent_pid == (pid_t)root_pid ||
                cw_pid_is_marked_descendant(parent_pid, relationships, relationship_count)
            ) {
                relationships[index].descendant = true;
                changed = true;
            }
        }
    }

    uint64_t descendant_resident_bytes = 0;
    int32_t descendant_count = 0;
    for (int index = 0; index < relationship_count; index++) {
        if (!relationships[index].descendant) {
            continue;
        }

        uint64_t resident_bytes = 0;
        if (cw_read_resident_bytes(relationships[index].pid, &resident_bytes)) {
            descendant_resident_bytes += resident_bytes;
            descendant_count++;
        }
    }

    free(pids);
    free(relationships);

    out_metrics->descendant_resident_bytes = descendant_resident_bytes;
    out_metrics->descendant_count = descendant_count;
    out_metrics->status = CW_STATUS_OK;
    return CW_STATUS_OK;
}

#ifndef CATALINA_PROCESS_METRICS_H
#define CATALINA_PROCESS_METRICS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t root_resident_bytes;
    uint64_t descendant_resident_bytes;
    int32_t descendant_count;
    int32_t status;
} CWProcessFamilyMetrics;

int32_t cw_read_process_family_metrics(int32_t root_pid, CWProcessFamilyMetrics *out_metrics);

#ifdef __cplusplus
}
#endif

#endif

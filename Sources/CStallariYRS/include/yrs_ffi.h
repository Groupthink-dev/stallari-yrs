#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Opaque awareness state container.
 * Stores per-client JSON state (cursor position, selection, user info).
 */
typedef struct YrsAwareness YrsAwareness;

/**
 * Opaque handle to a Yrs document.
 */
typedef struct YrsDoc YrsDoc;

/**
 * Opaque handle to a Yrs Text type reference.
 * Stores the name used to look up the text root from the document.
 */
typedef struct YrsTextRef YrsTextRef;

/**
 * Create a new Yrs document with a random client ID.
 */
 struct YrsDoc *yrs_doc_new(void) ;

/**
 * Create a new Yrs document with a specific client ID.
 * This is important for deterministic author attribution.
 */
 struct YrsDoc *yrs_doc_new_with_client_id(uint64_t client_id) ;

/**
 * Free a Yrs document.
 *
 * # Safety
 * `doc` must be a valid pointer returned by `yrs_doc_new*`.
 */
 void yrs_doc_free(struct YrsDoc *doc) ;

/**
 * Get the client ID of a document.
 *
 * # Safety
 * `doc` must be a valid pointer.
 */
 uint64_t yrs_doc_client_id(const struct YrsDoc *doc) ;

/**
 * Encode the full document state as a binary update (V2 encoding).
 * Caller must free the returned buffer with `yrs_buf_free`.
 *
 * # Safety
 * `doc` must be a valid pointer. `out_len` must be a valid pointer.
 */
 uint8_t *yrs_doc_encode_state_as_update_v2(const struct YrsDoc *doc, uintptr_t *out_len) ;

/**
 * Apply a binary update (V2 encoding) to the document.
 * Returns 0 on success, -1 on failure.
 *
 * # Safety
 * `doc` must be a valid pointer. `data` must point to `len` valid bytes.
 */
 int32_t yrs_doc_apply_update_v2(struct YrsDoc *doc, const uint8_t *data, uintptr_t len) ;

/**
 * Encode the document's state vector (for sync negotiation).
 * Caller must free the returned buffer with `yrs_buf_free`.
 *
 * # Safety
 * `doc` must be a valid pointer. `out_len` must be a valid pointer.
 */
 uint8_t *yrs_doc_encode_state_vector(const struct YrsDoc *doc, uintptr_t *out_len) ;

/**
 * Compute the diff (update) needed to bring a peer from `sv_data`
 * to the current document state. V2 encoding.
 * Caller must free the returned buffer with `yrs_buf_free`.
 *
 * # Safety
 * `doc` must be a valid pointer. `sv_data`/`sv_len` must be valid.
 * `out_len` must be a valid pointer.
 */

uint8_t *yrs_doc_encode_diff_v2(const struct YrsDoc *doc,
                                const uint8_t *sv_data,
                                uintptr_t sv_len,
                                uintptr_t *out_len)
;

/**
 * Get or create a named text type from the document.
 * The returned handle is valid for the lifetime of the document.
 *
 * # Safety
 * `doc` must be a valid pointer. `name` must be a valid C string.
 */
 struct YrsTextRef *yrs_doc_get_text(const struct YrsDoc *doc, const char *name) ;

/**
 * Free a text reference handle.
 *
 * # Safety
 * `text` must be a valid pointer returned by `yrs_doc_get_text`.
 */
 void yrs_text_free(struct YrsTextRef *text) ;

/**
 * Insert a string at the given index in the text.
 * Returns 0 on success, -1 on failure.
 *
 * # Safety
 * `doc` must be a valid pointer (needed for transaction).
 * `text` must be a valid pointer. `value` must be a valid C string.
 */

int32_t yrs_text_insert(struct YrsDoc *doc,
                        const struct YrsTextRef *text,
                        uint32_t index,
                        const char *value)
;

/**
 * Delete `length` characters starting at `index`.
 * Returns 0 on success, -1 on failure.
 *
 * # Safety
 * `doc` must be a valid pointer. `text` must be a valid pointer.
 */

int32_t yrs_text_delete(struct YrsDoc *doc,
                        const struct YrsTextRef *text,
                        uint32_t index,
                        uint32_t length)
;

/**
 * Get the full text content as a C string.
 * Caller must free the returned string with `yrs_string_free`.
 *
 * # Safety
 * `doc` must be a valid pointer. `text` must be a valid pointer.
 */
 char *yrs_text_to_string(const struct YrsDoc *doc, const struct YrsTextRef *text) ;

/**
 * Get the length of the text in UTF-8 code points.
 *
 * # Safety
 * `doc` must be a valid pointer. `text` must be a valid pointer.
 */
 uint32_t yrs_text_len(const struct YrsDoc *doc, const struct YrsTextRef *text) ;

/**
 * Create a new awareness instance for the given client ID.
 */
 struct YrsAwareness *yrs_awareness_new(uint64_t client_id) ;

/**
 * Free an awareness instance.
 *
 * # Safety
 * `awareness` must be a valid pointer.
 */
 void yrs_awareness_free(struct YrsAwareness *awareness) ;

/**
 * Set the local awareness state (JSON bytes).
 *
 * # Safety
 * `awareness` must be a valid pointer. `data`/`len` must be valid.
 */

void yrs_awareness_set_local_state(struct YrsAwareness *awareness,
                                   const uint8_t *data,
                                   uintptr_t len)
;

/**
 * Apply a remote awareness update.
 * Format: 8 bytes client_id (big-endian) + 4 bytes state_len (big-endian) + state bytes.
 * Returns 0 on success, -1 on failure.
 *
 * # Safety
 * `awareness` must be a valid pointer. `data`/`len` must be valid.
 */

int32_t yrs_awareness_apply_update(struct YrsAwareness *awareness,
                                   const uint8_t *data,
                                   uintptr_t len)
;

/**
 * Encode the local awareness state for transmission.
 * Format: 8 bytes client_id (big-endian) + 4 bytes state_len (big-endian) + state bytes.
 * Caller must free with `yrs_buf_free`.
 *
 * # Safety
 * `awareness` must be a valid pointer. `out_len` must be a valid pointer.
 */
 uint8_t *yrs_awareness_encode_update(const struct YrsAwareness *awareness, uintptr_t *out_len) ;

/**
 * Get the number of known remote clients in the awareness state.
 *
 * # Safety
 * `awareness` must be a valid pointer.
 */
 uint32_t yrs_awareness_client_count(const struct YrsAwareness *awareness) ;

/**
 * Get the state for a specific client ID.
 * Returns null if the client is unknown.
 * Caller must free the returned buffer with `yrs_buf_free`.
 *
 * # Safety
 * `awareness` must be a valid pointer. `out_len` must be a valid pointer.
 */

uint8_t *yrs_awareness_get_client_state(const struct YrsAwareness *awareness,
                                        uint64_t client_id,
                                        uintptr_t *out_len)
;

/**
 * Free a buffer returned by any `yrs_*` function.
 *
 * # Safety
 * `buf` must be a pointer returned by a `yrs_*` function, or null.
 */
 void yrs_buf_free(uint8_t *buf) ;

/**
 * Free a C string returned by `yrs_text_to_string`.
 *
 * # Safety
 * `s` must be a pointer returned by `yrs_text_to_string`, or null.
 */
 void yrs_string_free(char *s) ;

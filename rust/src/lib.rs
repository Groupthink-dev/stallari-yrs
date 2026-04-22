use std::ffi::{c_char, CStr, CString};
use std::ptr;
use std::slice;
use std::sync::Arc;
use yrs::updates::decoder::Decode;
use yrs::updates::encoder::Encode;
use yrs::{Doc, GetString, Options, ReadTxn, Text, Transact};

// ---------------------------------------------------------------------------
// YrsDoc
// ---------------------------------------------------------------------------

/// Opaque handle to a Yrs document.
pub struct YrsDoc {
    doc: Doc,
}

/// Create a new Yrs document with a random client ID.
#[no_mangle]
pub extern "C" fn yrs_doc_new() -> *mut YrsDoc {
    let doc = Doc::with_options(Options::default());
    Box::into_raw(Box::new(YrsDoc { doc }))
}

/// Create a new Yrs document with a specific client ID.
/// This is important for deterministic author attribution.
#[no_mangle]
pub extern "C" fn yrs_doc_new_with_client_id(client_id: u64) -> *mut YrsDoc {
    let doc = Doc::with_client_id(client_id);
    Box::into_raw(Box::new(YrsDoc { doc }))
}

/// Free a Yrs document.
///
/// # Safety
/// `doc` must be a valid pointer returned by `yrs_doc_new*`.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_free(doc: *mut YrsDoc) {
    if !doc.is_null() {
        drop(Box::from_raw(doc));
    }
}

/// Get the client ID of a document.
///
/// # Safety
/// `doc` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_client_id(doc: *const YrsDoc) -> u64 {
    (*doc).doc.client_id()
}

/// Encode the full document state as a binary update (V2 encoding).
/// Caller must free the returned buffer with `yrs_buf_free`.
///
/// # Safety
/// `doc` must be a valid pointer. `out_len` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_encode_state_as_update_v2(
    doc: *const YrsDoc,
    out_len: *mut usize,
) -> *mut u8 {
    let txn = (*doc).doc.transact();
    let update = txn.encode_state_as_update_v2(&yrs::StateVector::default());
    *out_len = update.len();
    let buf = vec_to_malloc_buf(&update);
    buf
}

/// Apply a binary update (V2 encoding) to the document.
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// `doc` must be a valid pointer. `data` must point to `len` valid bytes.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_apply_update_v2(
    doc: *mut YrsDoc,
    data: *const u8,
    len: usize,
) -> i32 {
    let bytes = slice::from_raw_parts(data, len);
    let update = match yrs::Update::decode_v2(bytes) {
        Ok(u) => u,
        Err(_) => return -1,
    };
    let mut txn = (*doc).doc.transact_mut();
    match txn.apply_update(update) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Encode the document's state vector (for sync negotiation).
/// Caller must free the returned buffer with `yrs_buf_free`.
///
/// # Safety
/// `doc` must be a valid pointer. `out_len` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_encode_state_vector(
    doc: *const YrsDoc,
    out_len: *mut usize,
) -> *mut u8 {
    let txn = (*doc).doc.transact();
    let sv = txn.state_vector().encode_v1();
    *out_len = sv.len();
    vec_to_malloc_buf(&sv)
}

/// Compute the diff (update) needed to bring a peer from `sv_data`
/// to the current document state. V2 encoding.
/// Caller must free the returned buffer with `yrs_buf_free`.
///
/// # Safety
/// `doc` must be a valid pointer. `sv_data`/`sv_len` must be valid.
/// `out_len` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_encode_diff_v2(
    doc: *const YrsDoc,
    sv_data: *const u8,
    sv_len: usize,
    out_len: *mut usize,
) -> *mut u8 {
    let sv_bytes = slice::from_raw_parts(sv_data, sv_len);
    let sv = match yrs::StateVector::decode_v1(sv_bytes) {
        Ok(v) => v,
        Err(_) => {
            *out_len = 0;
            return ptr::null_mut();
        }
    };
    let txn = (*doc).doc.transact();
    let diff = txn.encode_state_as_update_v2(&sv);
    *out_len = diff.len();
    vec_to_malloc_buf(&diff)
}

// ---------------------------------------------------------------------------
// YrsText
// ---------------------------------------------------------------------------

/// Opaque handle to a Yrs Text type reference.
/// Stores the name used to look up the text root from the document.
pub struct YrsTextRef {
    name: Arc<str>,
}

/// Get or create a named text type from the document.
/// The returned handle is valid for the lifetime of the document.
///
/// # Safety
/// `doc` must be a valid pointer. `name` must be a valid C string.
#[no_mangle]
pub unsafe extern "C" fn yrs_doc_get_text(
    doc: *const YrsDoc,
    name: *const c_char,
) -> *mut YrsTextRef {
    let name_str: Arc<str> = CStr::from_ptr(name).to_string_lossy().into_owned().into();
    // Touch the text root to ensure it exists
    let _text = (*doc).doc.get_or_insert_text(Arc::clone(&name_str));
    Box::into_raw(Box::new(YrsTextRef { name: name_str }))
}

/// Free a text reference handle.
///
/// # Safety
/// `text` must be a valid pointer returned by `yrs_doc_get_text`.
#[no_mangle]
pub unsafe extern "C" fn yrs_text_free(text: *mut YrsTextRef) {
    if !text.is_null() {
        drop(Box::from_raw(text));
    }
}

/// Insert a string at the given index in the text.
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// `doc` must be a valid pointer (needed for transaction).
/// `text` must be a valid pointer. `value` must be a valid C string.
#[no_mangle]
pub unsafe extern "C" fn yrs_text_insert(
    doc: *mut YrsDoc,
    text: *const YrsTextRef,
    index: u32,
    value: *const c_char,
) -> i32 {
    let val = CStr::from_ptr(value).to_string_lossy();
    let text_ref = (*doc).doc.get_or_insert_text(Arc::clone(&(*text).name));
    let mut txn = (*doc).doc.transact_mut();
    text_ref.insert(&mut txn, index, &val);
    0
}

/// Delete `length` characters starting at `index`.
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// `doc` must be a valid pointer. `text` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_text_delete(
    doc: *mut YrsDoc,
    text: *const YrsTextRef,
    index: u32,
    length: u32,
) -> i32 {
    let text_ref = (*doc).doc.get_or_insert_text(Arc::clone(&(*text).name));
    let mut txn = (*doc).doc.transact_mut();
    text_ref.remove_range(&mut txn, index, length);
    0
}

/// Get the full text content as a C string.
/// Caller must free the returned string with `yrs_string_free`.
///
/// # Safety
/// `doc` must be a valid pointer. `text` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_text_to_string(
    doc: *const YrsDoc,
    text: *const YrsTextRef,
) -> *mut c_char {
    let text_ref = (*doc).doc.get_or_insert_text(Arc::clone(&(*text).name));
    let txn = (*doc).doc.transact();
    let content = text_ref.get_string(&txn);
    match CString::new(content) {
        Ok(c) => c.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// Get the length of the text in UTF-8 code points.
///
/// # Safety
/// `doc` must be a valid pointer. `text` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_text_len(doc: *const YrsDoc, text: *const YrsTextRef) -> u32 {
    let text_ref = (*doc).doc.get_or_insert_text(Arc::clone(&(*text).name));
    let txn = (*doc).doc.transact();
    text_ref.len(&txn)
}

// ---------------------------------------------------------------------------
// Awareness
// ---------------------------------------------------------------------------

/// Opaque awareness state container.
/// Stores per-client JSON state (cursor position, selection, user info).
pub struct YrsAwareness {
    states: std::collections::HashMap<u64, Vec<u8>>,
    local_client_id: u64,
    local_state: Option<Vec<u8>>,
}

/// Create a new awareness instance for the given client ID.
#[no_mangle]
pub extern "C" fn yrs_awareness_new(client_id: u64) -> *mut YrsAwareness {
    Box::into_raw(Box::new(YrsAwareness {
        states: std::collections::HashMap::new(),
        local_client_id: client_id,
        local_state: None,
    }))
}

/// Free an awareness instance.
///
/// # Safety
/// `awareness` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_free(awareness: *mut YrsAwareness) {
    if !awareness.is_null() {
        drop(Box::from_raw(awareness));
    }
}

/// Set the local awareness state (JSON bytes).
///
/// # Safety
/// `awareness` must be a valid pointer. `data`/`len` must be valid.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_set_local_state(
    awareness: *mut YrsAwareness,
    data: *const u8,
    len: usize,
) {
    let bytes = slice::from_raw_parts(data, len).to_vec();
    let aw = &mut *awareness;
    aw.local_state = Some(bytes.clone());
    aw.states.insert(aw.local_client_id, bytes);
}

/// Apply a remote awareness update.
/// Format: 8 bytes client_id (big-endian) + 4 bytes state_len (big-endian) + state bytes.
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// `awareness` must be a valid pointer. `data`/`len` must be valid.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_apply_update(
    awareness: *mut YrsAwareness,
    data: *const u8,
    len: usize,
) -> i32 {
    if len < 12 {
        return -1;
    }
    let bytes = slice::from_raw_parts(data, len);
    let client_id = u64::from_be_bytes(bytes[0..8].try_into().unwrap());
    let state_len = u32::from_be_bytes(bytes[8..12].try_into().unwrap()) as usize;
    if 12 + state_len > len {
        return -1;
    }
    let state = bytes[12..12 + state_len].to_vec();
    (*awareness).states.insert(client_id, state);
    0
}

/// Encode the local awareness state for transmission.
/// Format: 8 bytes client_id (big-endian) + 4 bytes state_len (big-endian) + state bytes.
/// Caller must free with `yrs_buf_free`.
///
/// # Safety
/// `awareness` must be a valid pointer. `out_len` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_encode_update(
    awareness: *const YrsAwareness,
    out_len: *mut usize,
) -> *mut u8 {
    let aw = &*awareness;
    let state = match &aw.local_state {
        Some(s) => s,
        None => {
            *out_len = 0;
            return ptr::null_mut();
        }
    };
    let total = 8 + 4 + state.len();
    let buf = libc::malloc(total) as *mut u8;
    let client_bytes = aw.local_client_id.to_be_bytes();
    let len_bytes = (state.len() as u32).to_be_bytes();
    ptr::copy_nonoverlapping(client_bytes.as_ptr(), buf, 8);
    ptr::copy_nonoverlapping(len_bytes.as_ptr(), buf.add(8), 4);
    ptr::copy_nonoverlapping(state.as_ptr(), buf.add(12), state.len());
    *out_len = total;
    buf
}

/// Get the number of known remote clients in the awareness state.
///
/// # Safety
/// `awareness` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_client_count(awareness: *const YrsAwareness) -> u32 {
    (*awareness).states.len() as u32
}

/// Get the state for a specific client ID.
/// Returns null if the client is unknown.
/// Caller must free the returned buffer with `yrs_buf_free`.
///
/// # Safety
/// `awareness` must be a valid pointer. `out_len` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn yrs_awareness_get_client_state(
    awareness: *const YrsAwareness,
    client_id: u64,
    out_len: *mut usize,
) -> *mut u8 {
    match (*awareness).states.get(&client_id) {
        Some(state) => {
            *out_len = state.len();
            let buf = libc::malloc(state.len()) as *mut u8;
            ptr::copy_nonoverlapping(state.as_ptr(), buf, state.len());
            buf
        }
        None => {
            *out_len = 0;
            ptr::null_mut()
        }
    }
}

// ---------------------------------------------------------------------------
// Memory management helpers
// ---------------------------------------------------------------------------

/// Allocate a libc buffer and copy bytes into it.
/// Caller must free with `yrs_buf_free`.
unsafe fn vec_to_malloc_buf(data: &[u8]) -> *mut u8 {
    let buf = libc::malloc(data.len()) as *mut u8;
    ptr::copy_nonoverlapping(data.as_ptr(), buf, data.len());
    buf
}

/// Free a buffer returned by any `yrs_*` function.
///
/// # Safety
/// `buf` must be a pointer returned by a `yrs_*` function, or null.
#[no_mangle]
pub unsafe extern "C" fn yrs_buf_free(buf: *mut u8) {
    if !buf.is_null() {
        libc::free(buf as *mut libc::c_void);
    }
}

/// Free a C string returned by `yrs_text_to_string`.
///
/// # Safety
/// `s` must be a pointer returned by `yrs_text_to_string`, or null.
#[no_mangle]
pub unsafe extern "C" fn yrs_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

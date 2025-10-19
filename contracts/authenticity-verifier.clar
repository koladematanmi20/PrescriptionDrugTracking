;; Authenticity Verifier Contract
;; Verifies drug authenticity and proper storage conditions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-exists (err u302))
(define-constant err-unauthorized (err u303))
(define-constant err-invalid-data (err u304))
(define-constant err-verification-failed (err u305))
(define-constant err-expired (err u306))
(define-constant err-temperature-breach (err u307))
(define-constant err-humidity-breach (err u308))

;; Data Variables
(define-data-var next-verification-id uint u1)
(define-data-var next-alert-id uint u1)

;; Data Maps
(define-map verifications
  { verification-id: uint }
  {
    drug-id: uint,
    batch-number: (string-ascii 50),
    ndc-number: (string-ascii 20),
    verifier: principal,
    verification-type: (string-ascii 30),
    verification-result: bool,
    verification-score: uint,
    timestamp: uint,
    location: (string-ascii 200),
    temperature: int,
    humidity: uint,
    notes: (string-ascii 500),
    qr-code-hash: (buff 32)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  {
    authorized: bool,
    verifier-type: (string-ascii 20),
    organization: (string-ascii 100),
    license-number: (string-ascii 50),
    authorized-at: uint,
    authorized-by: principal
  }
)

(define-map storage-alerts
  { alert-id: uint }
  {
    drug-id: uint,
    location-id: uint,
    alert-type: (string-ascii 30),
    severity: (string-ascii 10),
    current-temperature: int,
    required-temp-min: int,
    required-temp-max: int,
    current-humidity: uint,
    required-humidity-min: uint,
    required-humidity-max: uint,
    timestamp: uint,
    resolved: bool,
    resolved-by: (optional principal),
    resolved-at: (optional uint)
  }
)

(define-map drug-authenticity-records
  { drug-id: uint }
  {
    total-verifications: uint,
    successful-verifications: uint,
    failed-verifications: uint,
    last-verification: uint,
    authenticity-score: uint,
    risk-level: (string-ascii 10)
  }
)

(define-map qr-code-registry
  { qr-hash: (buff 32) }
  {
    drug-id: uint,
    batch-number: (string-ascii 50),
    generated-at: uint,
    is-active: bool
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-verifier)
  (default-to false
    (get authorized (map-get? authorized-verifiers { verifier: tx-sender }))
  )
)

(define-private (calculate-authenticity-score (total uint) (successful uint))
  (if (is-eq total u0)
    u100
    (/ (* successful u100) total)
  )
)

(define-private (determine-risk-level (score uint))
  (if (>= score u90)
    "low"
    (if (>= score u70)
      "medium"
      "high"
    )
  )
)

(define-private (is-temperature-within-range (current int) (min-temp int) (max-temp int))
  (and (>= current min-temp) (<= current max-temp))
)

(define-private (is-humidity-within-range (current uint) (min-humidity uint) (max-humidity uint))
  (and (>= current min-humidity) (<= current max-humidity))
)

;; Public Functions

;; Authorize a verifier (only contract owner)
(define-public (authorize-verifier
  (verifier principal)
  (verifier-type (string-ascii 20))
  (organization (string-ascii 100))
  (license-number (string-ascii 50))
)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (> (len verifier-type) u0) err-invalid-data)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: true,
        verifier-type: verifier-type,
        organization: organization,
        license-number: license-number,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Generate QR code for drug (authorized verifiers only)
(define-public (generate-qr-code
  (drug-id uint)
  (batch-number (string-ascii 50))
  (qr-hash (buff 32))
)
  (begin
    (asserts! (is-authorized-verifier) err-unauthorized)
    (asserts! (is-none (map-get? qr-code-registry { qr-hash: qr-hash })) err-already-exists)
    
    (map-set qr-code-registry
      { qr-hash: qr-hash }
      {
        drug-id: drug-id,
        batch-number: batch-number,
        generated-at: stacks-block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Perform drug verification (authorized verifiers only)
(define-public (verify-drug
  (drug-id uint)
  (batch-number (string-ascii 50))
  (ndc-number (string-ascii 20))
  (verification-type (string-ascii 30))
  (location (string-ascii 200))
  (temperature int)
  (humidity uint)
  (qr-code-hash (buff 32))
  (notes (string-ascii 500))
)
  (let (
    (verification-id (var-get next-verification-id))
    (qr-data (map-get? qr-code-registry { qr-hash: qr-code-hash }))
    (verification-result (and
      (is-some qr-data)
      (is-eq (get drug-id (unwrap-panic qr-data)) drug-id)
      (is-eq (get batch-number (unwrap-panic qr-data)) batch-number)
      (get is-active (unwrap-panic qr-data))
    ))
    (verification-score (if verification-result u100 u0))
  )
    (asserts! (is-authorized-verifier) err-unauthorized)
    
    ;; Record verification
    (map-set verifications
      { verification-id: verification-id }
      {
        drug-id: drug-id,
        batch-number: batch-number,
        ndc-number: ndc-number,
        verifier: tx-sender,
        verification-type: verification-type,
        verification-result: verification-result,
        verification-score: verification-score,
        timestamp: stacks-block-height,
        location: location,
        temperature: temperature,
        humidity: humidity,
        notes: notes,
        qr-code-hash: qr-code-hash
      }
    )
    
    ;; Update authenticity records
    (let (
      (current-record (default-to
        { total-verifications: u0, successful-verifications: u0, failed-verifications: u0, 
          last-verification: u0, authenticity-score: u100, risk-level: "low" }
        (map-get? drug-authenticity-records { drug-id: drug-id })
      ))
      (new-total (+ (get total-verifications current-record) u1))
      (new-successful (if verification-result 
                       (+ (get successful-verifications current-record) u1)
                       (get successful-verifications current-record)))
      (new-failed (if verification-result
                   (get failed-verifications current-record)
                   (+ (get failed-verifications current-record) u1)))
      (new-score (calculate-authenticity-score new-total new-successful))
    )
      (map-set drug-authenticity-records
        { drug-id: drug-id }
        {
          total-verifications: new-total,
          successful-verifications: new-successful,
          failed-verifications: new-failed,
          last-verification: stacks-block-height,
          authenticity-score: new-score,
          risk-level: (determine-risk-level new-score)
        }
      )
    )
    
    (var-set next-verification-id (+ verification-id u1))
    (ok { verification-id: verification-id, result: verification-result, score: verification-score })
  )
)

;; Report storage condition alert (authorized verifiers only)
(define-public (report-storage-alert
  (drug-id uint)
  (location-id uint)
  (alert-type (string-ascii 30))
  (severity (string-ascii 10))
  (current-temperature int)
  (required-temp-min int)
  (required-temp-max int)
  (current-humidity uint)
  (required-humidity-min uint)
  (required-humidity-max uint)
)
  (let (
    (alert-id (var-get next-alert-id))
  )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (asserts! (or (is-eq severity "low") (is-eq severity "medium") (is-eq severity "high")) err-invalid-data)
    
    (map-set storage-alerts
      { alert-id: alert-id }
      {
        drug-id: drug-id,
        location-id: location-id,
        alert-type: alert-type,
        severity: severity,
        current-temperature: current-temperature,
        required-temp-min: required-temp-min,
        required-temp-max: required-temp-max,
        current-humidity: current-humidity,
        required-humidity-min: required-humidity-min,
        required-humidity-max: required-humidity-max,
        timestamp: stacks-block-height,
        resolved: false,
        resolved-by: none,
        resolved-at: none
      }
    )
    
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

;; Resolve storage alert (authorized verifiers only)
(define-public (resolve-alert (alert-id uint))
  (let (
    (alert-data (unwrap! (map-get? storage-alerts { alert-id: alert-id }) err-not-found))
  )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (asserts! (not (get resolved alert-data)) err-invalid-data)
    
    (map-set storage-alerts
      { alert-id: alert-id }
      (merge alert-data {
        resolved: true,
        resolved-by: (some tx-sender),
        resolved-at: (some stacks-block-height)
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get verification details
(define-read-only (get-verification (verification-id uint))
  (map-get? verifications { verification-id: verification-id })
)

;; Get drug authenticity record
(define-read-only (get-authenticity-record (drug-id uint))
  (map-get? drug-authenticity-records { drug-id: drug-id })
)

;; Get storage alert
(define-read-only (get-storage-alert (alert-id uint))
  (map-get? storage-alerts { alert-id: alert-id })
)

;; Verify QR code
(define-read-only (verify-qr-code (qr-hash (buff 32)))
  (map-get? qr-code-registry { qr-hash: qr-hash })
)

;; Check if verifier is authorized
(define-read-only (is-verifier-authorized (verifier principal))
  (default-to false
    (get authorized (map-get? authorized-verifiers { verifier: verifier }))
  )
)

;; Get verifier details
(define-read-only (get-verifier-details (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

;; Check storage conditions
(define-read-only (check-storage-conditions
  (current-temp int)
  (required-temp-min int)
  (required-temp-max int)
  (current-humidity uint)
  (required-humidity-min uint)
  (required-humidity-max uint)
)
  {
    temperature-ok: (is-temperature-within-range current-temp required-temp-min required-temp-max),
    humidity-ok: (is-humidity-within-range current-humidity required-humidity-min required-humidity-max),
    overall-ok: (and
      (is-temperature-within-range current-temp required-temp-min required-temp-max)
      (is-humidity-within-range current-humidity required-humidity-min required-humidity-max)
    )
  }
)

;; Get verification count
(define-read-only (get-verification-count)
  (- (var-get next-verification-id) u1)
)

;; Get alert count
(define-read-only (get-alert-count)
  (- (var-get next-alert-id) u1)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  contract-owner
)

;; title: authenticity-verifier
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;


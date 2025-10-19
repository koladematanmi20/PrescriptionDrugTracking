;; Drug Registry Contract
;; Records authentic pharmaceutical products with unique identifiers

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-data (err u104))

;; Data Variables
(define-data-var next-drug-id uint u1)

;; Data Maps
(define-map drugs
  { drug-id: uint }
  {
    name: (string-ascii 100),
    manufacturer: principal,
    batch-number: (string-ascii 50),
    manufacture-date: uint,
    expiry-date: uint,
    dosage: (string-ascii 50),
    active-ingredient: (string-ascii 100),
    ndc-number: (string-ascii 20),
    lot-size: uint,
    is-active: bool,
    created-at: uint,
    created-by: principal
  }
)

(define-map drug-by-ndc
  { ndc-number: (string-ascii 20) }
  { drug-id: uint }
)

(define-map drug-by-batch
  { manufacturer: principal, batch-number: (string-ascii 50) }
  { drug-id: uint }
)

(define-map authorized-manufacturers
  { manufacturer: principal }
  { authorized: bool, authorized-at: uint, authorized-by: principal }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-manufacturer (manufacturer principal))
  (default-to false
    (get authorized (map-get? authorized-manufacturers { manufacturer: manufacturer }))
  )
)

(define-private (validate-drug-data (name (string-ascii 100))
                                  (batch-number (string-ascii 50))
                                  (manufacture-date uint)
                                  (expiry-date uint)
                                  (ndc-number (string-ascii 20))
                                  (lot-size uint))
  (and
    (> (len name) u0)
    (> (len batch-number) u0)
    (> (len ndc-number) u0)
    (> expiry-date manufacture-date)
    (> lot-size u0)
  )
)

;; Public Functions

;; Authorize a manufacturer (only contract owner)
(define-public (authorize-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      {
        authorized: true,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Revoke manufacturer authorization (only contract owner)
(define-public (revoke-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      {
        authorized: false,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Register a new drug (only authorized manufacturers)
(define-public (register-drug
  (name (string-ascii 100))
  (batch-number (string-ascii 50))
  (manufacture-date uint)
  (expiry-date uint)
  (dosage (string-ascii 50))
  (active-ingredient (string-ascii 100))
  (ndc-number (string-ascii 20))
  (lot-size uint)
)
  (let (
    (drug-id (var-get next-drug-id))
    (manufacturer tx-sender)
  )
    ;; Validate authorization and data
    (asserts! (is-authorized-manufacturer manufacturer) err-unauthorized)
    (asserts! (validate-drug-data name batch-number manufacture-date expiry-date ndc-number lot-size) err-invalid-data)
    
    ;; Check for duplicates
    (asserts! (is-none (map-get? drug-by-ndc { ndc-number: ndc-number })) err-already-exists)
    (asserts! (is-none (map-get? drug-by-batch { manufacturer: manufacturer, batch-number: batch-number })) err-already-exists)
    
    ;; Register the drug
    (map-set drugs
      { drug-id: drug-id }
      {
        name: name,
        manufacturer: manufacturer,
        batch-number: batch-number,
        manufacture-date: manufacture-date,
        expiry-date: expiry-date,
        dosage: dosage,
        active-ingredient: active-ingredient,
        ndc-number: ndc-number,
        lot-size: lot-size,
        is-active: true,
        created-at: stacks-block-height,
        created-by: tx-sender
      }
    )
    
    ;; Create lookup maps
    (map-set drug-by-ndc { ndc-number: ndc-number } { drug-id: drug-id })
    (map-set drug-by-batch { manufacturer: manufacturer, batch-number: batch-number } { drug-id: drug-id })
    
    ;; Update next drug ID
    (var-set next-drug-id (+ drug-id u1))
    
    (ok drug-id)
  )
)

;; Deactivate a drug (manufacturer or contract owner)
(define-public (deactivate-drug (drug-id uint))
  (let (
    (drug-data (unwrap! (map-get? drugs { drug-id: drug-id }) err-not-found))
    (manufacturer (get manufacturer drug-data))
  )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender manufacturer) (is-contract-owner)) err-unauthorized)
    
    ;; Deactivate the drug
    (map-set drugs
      { drug-id: drug-id }
      (merge drug-data { is-active: false })
    )
    
    (ok true)
  )
)

;; Reactivate a drug (manufacturer or contract owner)
(define-public (reactivate-drug (drug-id uint))
  (let (
    (drug-data (unwrap! (map-get? drugs { drug-id: drug-id }) err-not-found))
    (manufacturer (get manufacturer drug-data))
  )
    ;; Check authorization
    (asserts! (or (is-eq tx-sender manufacturer) (is-contract-owner)) err-unauthorized)
    
    ;; Reactivate the drug
    (map-set drugs
      { drug-id: drug-id }
      (merge drug-data { is-active: true })
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get drug by ID
(define-read-only (get-drug (drug-id uint))
  (map-get? drugs { drug-id: drug-id })
)

;; Get drug by NDC number
(define-read-only (get-drug-by-ndc (ndc-number (string-ascii 20)))
  (match (map-get? drug-by-ndc { ndc-number: ndc-number })
    lookup-result (map-get? drugs { drug-id: (get drug-id lookup-result) })
    none
  )
)

;; Get drug by manufacturer and batch
(define-read-only (get-drug-by-batch (manufacturer principal) (batch-number (string-ascii 50)))
  (match (map-get? drug-by-batch { manufacturer: manufacturer, batch-number: batch-number })
    lookup-result (map-get? drugs { drug-id: (get drug-id lookup-result) })
    none
  )
)

;; Check if manufacturer is authorized
(define-read-only (is-manufacturer-authorized (manufacturer principal))
  (is-authorized-manufacturer manufacturer)
)

;; Get manufacturer authorization details
(define-read-only (get-manufacturer-authorization (manufacturer principal))
  (map-get? authorized-manufacturers { manufacturer: manufacturer })
)

;; Check if drug is active and not expired
(define-read-only (is-drug-valid (drug-id uint))
  (match (map-get? drugs { drug-id: drug-id })
    drug-data (and
      (get is-active drug-data)
      (>= (get expiry-date drug-data) stacks-block-height)
    )
    false
  )
)

;; Get current drug count
(define-read-only (get-drug-count)
  (- (var-get next-drug-id) u1)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  contract-owner
)

;; title: drug-registry
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


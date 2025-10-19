;; Supply Tracker Contract
;; Tracks drug movement through distribution channels

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-unauthorized (err u203))
(define-constant err-invalid-data (err u204))
(define-constant err-invalid-status (err u205))

;; Data Variables
(define-data-var next-shipment-id uint u1)
(define-data-var next-location-id uint u1)

;; Data Maps
(define-map shipments
  { shipment-id: uint }
  {
    drug-id: uint,
    batch-number: (string-ascii 50),
    quantity: uint,
    from-location: uint,
    to-location: uint,
    status: (string-ascii 20),
    created-at: uint,
    created-by: principal,
    updated-at: uint,
    updated-by: principal,
    temperature-min: int,
    temperature-max: int,
    humidity-min: uint,
    humidity-max: uint,
    estimated-delivery: uint,
    actual-delivery: (optional uint)
  }
)

(define-map locations
  { location-id: uint }
  {
    name: (string-ascii 100),
    address: (string-ascii 200),
    location-type: (string-ascii 20),
    contact-person: (string-ascii 100),
    phone: (string-ascii 20),
    email: (string-ascii 100),
    license-number: (string-ascii 50),
    is-active: bool,
    created-at: uint,
    created-by: principal
  }
)

(define-map authorized-handlers
  { handler: principal }
  { authorized: bool, location-id: uint, authorized-at: uint, authorized-by: principal }
)

(define-map shipment-tracking
  { shipment-id: uint, sequence: uint }
  {
    timestamp: uint,
    location: (string-ascii 200),
    status: (string-ascii 50),
    temperature: int,
    humidity: uint,
    handler: principal,
    notes: (string-ascii 500)
  }
)

(define-map drug-location-inventory
  { drug-id: uint, location-id: uint }
  { quantity: uint, last-updated: uint }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-handler)
  (default-to false
    (get authorized (map-get? authorized-handlers { handler: tx-sender }))
  )
)

(define-private (get-handler-location)
  (get location-id (map-get? authorized-handlers { handler: tx-sender }))
)

(define-private (is-valid-status (status (string-ascii 20)))
  (or
    (is-eq status "created")
    (is-eq status "picked-up")
    (is-eq status "in-transit")
    (is-eq status "delivered")
    (is-eq status "cancelled")
  )
)

(define-private (validate-temperature-range (min-temp int) (max-temp int))
  (>= max-temp min-temp)
)

(define-private (validate-humidity-range (min-humidity uint) (max-humidity uint))
  (and
    (>= max-humidity min-humidity)
    (<= max-humidity u100)
  )
)

;; Public Functions

;; Register a new location (only contract owner)
(define-public (register-location
  (name (string-ascii 100))
  (address (string-ascii 200))
  (location-type (string-ascii 20))
  (contact-person (string-ascii 100))
  (phone (string-ascii 20))
  (email (string-ascii 100))
  (license-number (string-ascii 50))
)
  (let (
    (location-id (var-get next-location-id))
  )
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (> (len name) u0) err-invalid-data)
    (asserts! (> (len address) u0) err-invalid-data)
    
    (map-set locations
      { location-id: location-id }
      {
        name: name,
        address: address,
        location-type: location-type,
        contact-person: contact-person,
        phone: phone,
        email: email,
        license-number: license-number,
        is-active: true,
        created-at: stacks-block-height,
        created-by: tx-sender
      }
    )
    
    (var-set next-location-id (+ location-id u1))
    (ok location-id)
  )
)

;; Authorize a handler for a location (only contract owner)
(define-public (authorize-handler (handler principal) (location-id uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (is-some (map-get? locations { location-id: location-id })) err-not-found)
    
    (map-set authorized-handlers
      { handler: handler }
      {
        authorized: true,
        location-id: location-id,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Create a new shipment (only authorized handlers)
(define-public (create-shipment
  (drug-id uint)
  (batch-number (string-ascii 50))
  (quantity uint)
  (to-location uint)
  (temperature-min int)
  (temperature-max int)
  (humidity-min uint)
  (humidity-max uint)
  (estimated-delivery uint)
)
  (let (
    (shipment-id (var-get next-shipment-id))
    (from-location (unwrap! (get-handler-location) err-unauthorized))
  )
    (asserts! (is-authorized-handler) err-unauthorized)
    (asserts! (> quantity u0) err-invalid-data)
    (asserts! (is-some (map-get? locations { location-id: to-location })) err-not-found)
    (asserts! (validate-temperature-range temperature-min temperature-max) err-invalid-data)
    (asserts! (validate-humidity-range humidity-min humidity-max) err-invalid-data)
    
    ;; Create shipment
    (map-set shipments
      { shipment-id: shipment-id }
      {
        drug-id: drug-id,
        batch-number: batch-number,
        quantity: quantity,
        from-location: from-location,
        to-location: to-location,
        status: "created",
        created-at: stacks-block-height,
        created-by: tx-sender,
        updated-at: stacks-block-height,
        updated-by: tx-sender,
        temperature-min: temperature-min,
        temperature-max: temperature-max,
        humidity-min: humidity-min,
        humidity-max: humidity-max,
        estimated-delivery: estimated-delivery,
        actual-delivery: none
      }
    )
    
    ;; Add initial tracking entry
    (map-set shipment-tracking
      { shipment-id: shipment-id, sequence: u0 }
      {
        timestamp: stacks-block-height,
        location: "Origin",
        status: "Shipment created",
        temperature: temperature-min,
        humidity: humidity-min,
        handler: tx-sender,
        notes: "Initial shipment creation"
      }
    )
    
    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)
  )
)

;; Update shipment status (only authorized handlers)
(define-public (update-shipment-status
  (shipment-id uint)
  (status (string-ascii 20))
  (current-location (string-ascii 200))
  (temperature int)
  (humidity uint)
  (notes (string-ascii 500))
)
  (let (
    (shipment-data (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found))
    (sequence u1)
  )
    (asserts! (is-authorized-handler) err-unauthorized)
    (asserts! (is-valid-status status) err-invalid-status)
    
    ;; Update shipment
    (map-set shipments
      { shipment-id: shipment-id }
      (merge shipment-data {
        status: status,
        updated-at: stacks-block-height,
        updated-by: tx-sender,
        actual-delivery: (if (is-eq status "delivered") (some stacks-block-height) (get actual-delivery shipment-data))
      })
    )
    
    ;; Add tracking entry
    (map-set shipment-tracking
      { shipment-id: shipment-id, sequence: (+ sequence u1) }
      {
        timestamp: stacks-block-height,
        location: current-location,
        status: status,
        temperature: temperature,
        humidity: humidity,
        handler: tx-sender,
        notes: notes
      }
    )
    
    ;; Update inventory if delivered
    (if (is-eq status "delivered")
      (let (
        (drug-id (get drug-id shipment-data))
        (to-location (get to-location shipment-data))
        (quantity (get quantity shipment-data))
        (current-inventory (default-to u0 (get quantity (map-get? drug-location-inventory { drug-id: drug-id, location-id: to-location }))))
      )
        (map-set drug-location-inventory
          { drug-id: drug-id, location-id: to-location }
          {
            quantity: (+ current-inventory quantity),
            last-updated: stacks-block-height
          }
        )
      )
      true
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get shipment details
(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { shipment-id: shipment-id })
)

;; Get location details
(define-read-only (get-location (location-id uint))
  (map-get? locations { location-id: location-id })
)

;; Get shipment tracking history
(define-read-only (get-tracking-entry (shipment-id uint) (sequence uint))
  (map-get? shipment-tracking { shipment-id: shipment-id, sequence: sequence })
)

;; Check if handler is authorized
(define-read-only (is-handler-authorized (handler principal))
  (default-to false
    (get authorized (map-get? authorized-handlers { handler: handler }))
  )
)

;; Get handler authorization details
(define-read-only (get-handler-authorization (handler principal))
  (map-get? authorized-handlers { handler: handler })
)

;; Get drug inventory at location
(define-read-only (get-drug-inventory (drug-id uint) (location-id uint))
  (map-get? drug-location-inventory { drug-id: drug-id, location-id: location-id })
)

;; Get shipment count
(define-read-only (get-shipment-count)
  (- (var-get next-shipment-id) u1)
)

;; Get location count
(define-read-only (get-location-count)
  (- (var-get next-location-id) u1)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  contract-owner
)

;; title: supply-tracker
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


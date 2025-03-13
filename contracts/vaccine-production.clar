;; Vaccine Production Contract
;; Tracks manufacturing details and batch information

(define-data-var manufacturer-counter uint u0)
(define-data-var vaccine-counter uint u0)
(define-data-var batch-counter uint u0)

(define-map manufacturers
{ id: uint }
{
  name: (string-ascii 64),
  location: (string-ascii 64),
  certification: (string-ascii 64),
  active: bool
}
)

(define-map vaccines
{ id: uint }
{
  name: (string-ascii 64),
  manufacturer-id: uint,
  doses-required: uint,
  days-between-doses: uint,
  storage-temp-min: int,
  storage-temp-max: int,
  active: bool
}
)

(define-map batches
{ id: uint }
{
  vaccine-id: uint,
  manufacturer-id: uint,
  production-date: uint,
  expiration-date: uint,
  quantity: uint,
  lot-number: (string-ascii 32),
  status: (string-ascii 16)
}
)

(define-map admins
{ address: principal }
{ active: bool }
)

;; Initialize contract with first admin
(define-public (initialize)
(begin
  (map-set admins { address: tx-sender } { active: true })
  (ok true)
)
)

;; Register a new manufacturer
(define-public (register-manufacturer
              (name (string-ascii 64))
              (location (string-ascii 64))
              (certification (string-ascii 64)))
(let ((new-id (+ (var-get manufacturer-counter) u1)))
  ;; Only admins can register manufacturers
  (asserts! (is-admin tx-sender) (err u1))

  ;; Update counter
  (var-set manufacturer-counter new-id)

  ;; Store manufacturer data
  (map-set manufacturers
    { id: new-id }
    {
      name: name,
      location: location,
      certification: certification,
      active: true
    }
  )

  (ok new-id)
)
)

;; Register a new vaccine
(define-public (register-vaccine
              (name (string-ascii 64))
              (manufacturer-id uint)
              (doses-required uint)
              (days-between-doses uint)
              (storage-temp-min int)
              (storage-temp-max int))
(let ((new-id (+ (var-get vaccine-counter) u1)))
  ;; Only admins can register vaccines
  (asserts! (is-admin tx-sender) (err u1))

  ;; Manufacturer must exist
  (asserts! (is-some (map-get? manufacturers { id: manufacturer-id })) (err u2))

  ;; Update counter
  (var-set vaccine-counter new-id)

  ;; Store vaccine data
  (map-set vaccines
    { id: new-id }
    {
      name: name,
      manufacturer-id: manufacturer-id,
      doses-required: doses-required,
      days-between-doses: days-between-doses,
      storage-temp-min: storage-temp-min,
      storage-temp-max: storage-temp-max,
      active: true
    }
  )

  (ok new-id)
)
)

;; Record a new batch
(define-public (record-batch
              (vaccine-id uint)
              (manufacturer-id uint)
              (production-date uint)
              (expiration-date uint)
              (quantity uint)
              (lot-number (string-ascii 32)))
(let ((new-id (+ (var-get batch-counter) u1)))
  ;; Only manufacturer or admin can record batches
  (asserts! (or
              (is-admin tx-sender)
              (is-manufacturer tx-sender manufacturer-id))
            (err u1))

  ;; Vaccine must exist
  (asserts! (is-some (map-get? vaccines { id: vaccine-id })) (err u2))

  ;; Update counter
  (var-set batch-counter new-id)

  ;; Store batch data
  (map-set batches
    { id: new-id }
    {
      vaccine-id: vaccine-id,
      manufacturer-id: manufacturer-id,
      production-date: production-date,
      expiration-date: expiration-date,
      quantity: quantity,
      lot-number: lot-number,
      status: "produced"
    }
  )

  (ok new-id)
)
)

;; Update batch status
(define-public (update-batch-status
              (batch-id uint)
              (status (string-ascii 16)))
(let ((batch (map-get? batches { id: batch-id })))
  ;; Only admin can update status
  (asserts! (is-admin tx-sender) (err u1))

  ;; Batch must exist
  (asserts! (is-some batch) (err u2))

  ;; Store updated batch
  (map-set batches
    { id: batch-id }
    (merge (unwrap-panic batch) { status: status })
  )

  (ok true)
)
)

;; Add an admin
(define-public (add-admin (address principal))
(begin
  ;; Only admins can add admins
  (asserts! (is-admin tx-sender) (err u1))

  (map-set admins
    { address: address }
    { active: true }
  )

  (ok true)
)
)

;; Get manufacturer details
(define-read-only (get-manufacturer (manufacturer-id uint))
(map-get? manufacturers { id: manufacturer-id })
)

;; Get vaccine details
(define-read-only (get-vaccine (vaccine-id uint))
(map-get? vaccines { id: vaccine-id })
)

;; Get batch details
(define-read-only (get-batch (batch-id uint))
(map-get? batches { id: batch-id })
)

;; Check if address is admin
(define-read-only (is-admin (address principal))
(default-to false (get active (map-get? admins { address: address })))
)

;; Check if address is manufacturer
(define-read-only (is-manufacturer (address principal) (manufacturer-id uint))
(let ((manufacturer (map-get? manufacturers { id: manufacturer-id })))
  (and
    (is-some manufacturer)
    (is-eq address (as-contract tx-sender))
  )
)
)

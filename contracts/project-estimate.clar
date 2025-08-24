;; Project Estimation Smart Contract
;; This contract provides a comprehensive system for creating, tracking, and validating 
;; project estimates within a decentralized ecosystem.

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ESTIMATE-NOT-FOUND (err u101))
(define-constant ERR-INVALID-ESTIMATE (err u102))
(define-constant ERR-ALREADY-FINALIZED (err u103))
(define-constant ERR-INVALID-STATUS (err u104))

;; Data Storage
(define-data-var contract-admin principal tx-sender)

;; Track different estimate types
(define-map estimate-types 
  { type-id: (string-ascii 24) }
  { 
    description: (string-utf8 100), 
    active: bool 
  }
)

;; Project estimates
(define-map project-estimates
  { estimate-id: uint }
  {
    project-name: (string-utf8 50),
    estimator: principal,
    estimate-type: (string-ascii 24),
    total-budget: uint,
    duration-blocks: uint,
    status: (string-ascii 12),
    created-at: uint,
    resources: (list 10 (string-utf8 50)),
    risk-level: uint
  }
)

;; Estimate revisions and validations
(define-map estimate-revisions
  { estimate-id: uint, revision-number: uint }
  {
    revised-budget: uint,
    revised-duration: uint,
    revision-notes: (string-utf8 200),
    revised-at: uint
  }
)

;; Validation tracking
(define-map estimate-validations
  { estimate-id: uint, validator: principal }
  {
    validated-at: uint,
    approval-status: bool,
    comments: (string-utf8 200)
  }
)

;; Counters
(define-data-var next-estimate-id uint u1)
(define-data-var total-project-estimates uint u0)

;; Private Functions
(define-private (is-contract-admin (sender principal))
  (is-eq sender (var-get contract-admin))
)

;; Read-Only Functions
(define-read-only (get-project-estimate (estimate-id uint))
  (map-get? project-estimates { estimate-id: estimate-id })
)

(define-read-only (get-estimate-type (type-id (string-ascii 24)))
  (map-get? estimate-types { type-id: type-id })
)

(define-read-only (get-total-project-estimates)
  (var-get total-project-estimates)
)

;; Public Functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-contract-admin tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

(define-public (register-estimate-type 
    (type-id (string-ascii 24))
    (description (string-utf8 100)))
  (begin
    (asserts! (is-contract-admin tx-sender) ERR-NOT-AUTHORIZED)
    (map-set estimate-types 
      { type-id: type-id }
      { 
        description: description, 
        active: true 
      }
    )
    (ok true)
  )
)

(define-public (create-project-estimate
    (project-name (string-utf8 50))
    (estimate-type (string-ascii 24))
    (total-budget uint)
    (duration-blocks uint)
    (resources (list 10 (string-utf8 50)))
    (risk-level uint))
  (let (
    (estimate-id (var-get next-estimate-id))
    (now-block-height block-height)
    (type-info (unwrap! (map-get? estimate-types { type-id: estimate-type }) ERR-INVALID-ESTIMATE))
  )
    (asserts! (get active type-info) ERR-INVALID-ESTIMATE)
    (asserts! (> total-budget u0) ERR-INVALID-ESTIMATE)
    (asserts! (> duration-blocks u0) ERR-INVALID-ESTIMATE)
    
    (map-set project-estimates
      { estimate-id: estimate-id }
      {
        project-name: project-name,
        estimator: tx-sender,
        estimate-type: estimate-type,
        total-budget: total-budget,
        duration-blocks: duration-blocks,
        status: "draft",
        created-at: now-block-height,
        resources: resources,
        risk-level: risk-level
      }
    )
    
    (var-set next-estimate-id (+ estimate-id u1))
    (var-set total-project-estimates (+ (var-get total-project-estimates) u1))
    
    (ok estimate-id)
  )
)

(define-public (update-project-estimate
    (estimate-id uint)
    (total-budget (optional uint))
    (duration-blocks (optional uint))
    (resources (optional (list 10 (string-utf8 50))))
    (risk-level (optional uint)))
  (let (
    (current-estimate (unwrap! (map-get? project-estimates { estimate-id: estimate-id }) ERR-ESTIMATE-NOT-FOUND))
    (now-block-height block-height)
  )
    (asserts! (is-eq (get estimator current-estimate) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status current-estimate) "draft") ERR-INVALID-STATUS)
    
    (map-set project-estimates
      { estimate-id: estimate-id }
      (merge current-estimate 
        {
          total-budget: (default-to (get total-budget current-estimate) total-budget),
          duration-blocks: (default-to (get duration-blocks current-estimate) duration-blocks),
          resources: (default-to (get resources current-estimate) resources),
          risk-level: (default-to (get risk-level current-estimate) risk-level)
        }
      )
    )
    
    (map-set estimate-revisions
      { estimate-id: estimate-id, revision-number: u1 }
      {
        revised-budget: (default-to (get total-budget current-estimate) total-budget),
        revised-duration: (default-to (get duration-blocks current-estimate) duration-blocks),
        revision-notes: "Estimate update",
        revised-at: now-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (validate-project-estimate
    (estimate-id uint)
    (approved bool)
    (comments (string-utf8 200)))
  (let (
    (current-estimate (unwrap! (map-get? project-estimates { estimate-id: estimate-id }) ERR-ESTIMATE-NOT-FOUND))
    (now-block-height block-height)
  )
    (asserts! (is-eq (get status current-estimate) "draft") ERR-INVALID-STATUS)
    
    (map-set estimate-validations
      { estimate-id: estimate-id, validator: tx-sender }
      {
        validated-at: now-block-height,
        approval-status: approved,
        comments: comments
      }
    )
    
    (if approved
        (map-set project-estimates
          { estimate-id: estimate-id }
          (merge current-estimate { status: "approved" })
        )
        (map-set project-estimates
          { estimate-id: estimate-id }
          (merge current-estimate { status: "rejected" })
        )
    )
    
    (ok true)
  )
)
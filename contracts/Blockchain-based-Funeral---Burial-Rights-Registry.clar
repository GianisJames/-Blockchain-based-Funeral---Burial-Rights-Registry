(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-witness (err u104))
(define-constant err-consensus-not-met (err u105))

(define-non-fungible-token burial-plot uint)

(define-map burial-records
    uint 
    {
        owner: principal,
        location: (string-ascii 64),
        gps-lat: int,
        gps-long: int,
        last-wishes: (string-ascii 256),
        status: (string-ascii 12),
        witnesses: (list 10 principal),
        family-votes: uint,
        required-votes: uint
    }
)

(define-map family-members 
    { plot-id: uint, member: principal } 
    bool
)

(define-map witness-signatures
    { plot-id: uint, witness: principal }
    bool
)

(define-data-var next-plot-id uint u1)

(define-public (register-burial-plot 
    (location (string-ascii 64))
    (gps-lat int)
    (gps-long int)
    (last-wishes (string-ascii 256))
    (required-votes uint))
    (let ((plot-id (var-get next-plot-id)))
        (try! (nft-mint? burial-plot plot-id tx-sender))
        (map-set burial-records plot-id {
            owner: tx-sender,
            location: location,
            gps-lat: gps-lat,
            gps-long: gps-long,
            last-wishes: last-wishes,
            status: "active",
            witnesses: (list),
            family-votes: u0,
            required-votes: required-votes
        })
        (var-set next-plot-id (+ plot-id u1))
        (ok plot-id)))

(define-public (add-family-member (plot-id uint) (member principal))
    (let ((record (unwrap! (map-get? burial-records plot-id) err-not-found)))
        (asserts! (is-eq (get owner record) tx-sender) err-owner-only)
        (map-set family-members {plot-id: plot-id, member: member} true)
        (ok true)))

(define-public (add-witness (plot-id uint) (witness principal))
    (let ((record (unwrap! (map-get? burial-records plot-id) err-not-found)))
        (asserts! (is-eq (get owner record) tx-sender) err-owner-only)
        (let ((current-witnesses (get witnesses record)))

            (asserts! (< (len current-witnesses) u10) (err u100))
            (map-set burial-records plot-id 

                (merge record {witnesses: (unwrap! (as-max-len? (append current-witnesses witness) u10) (err u100))}))
            (ok true))))
(define-public (witness-sign (plot-id uint))
    (let ((record (unwrap! (map-get? burial-records plot-id) err-not-found)))
        (asserts! (is-some (index-of (get witnesses record) tx-sender)) err-invalid-witness)
        (map-set witness-signatures {plot-id: plot-id, witness: tx-sender} true)
        (ok true)))

(define-public (vote-on-plot (plot-id uint))
    (let ((record (unwrap! (map-get? burial-records plot-id) err-not-found))
          (is-family (unwrap! (map-get? family-members {plot-id: plot-id, member: tx-sender}) err-unauthorized)))
        (asserts! is-family err-unauthorized)
        (map-set burial-records plot-id 
            (merge record {family-votes: (+ (get family-votes record) u1)}))
        (ok true)))

(define-read-only (get-burial-record (plot-id uint))
    (map-get? burial-records plot-id))

(define-read-only (is-witness-signed (plot-id uint) (witness principal))
    (default-to false (map-get? witness-signatures {plot-id: plot-id, witness: witness})))

(define-read-only (get-consensus-status (plot-id uint))
    (let ((record (unwrap! (map-get? burial-records plot-id) err-not-found)))
        (if (>= (get family-votes record) (get required-votes record))
            (ok true)
            err-consensus-not-met)))
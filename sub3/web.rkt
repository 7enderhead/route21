#lang scribble/lp2

@defmodule["web.rkt"]

@title[#:tag "web"]{route21 Static Web Application}

@section{General Sequence}

@itemlist[
 @item{request to render a specific 'tab'}
 @item{tabbing produces sites using}
 @item{the formlet for a tab}
 @item{global state for session is tracked and used to}
 @item{prefill already entered data}
 @item{extracted from HTTP request and further processed (e.g., data display)}
 ]

@section{Module Data}

@itemlist[
 @item{@racket[data-provider<%>] interface and implementation from GUI reused}
 @item{static pre-sorted stop list is cached, since stops never change}
 ]

@chunk[<module-data>
       (define info (get-info/full "."))

       (define provider (data-provider))

       (define stops (~> (send provider stops)
                         (sort (lambda (stop1 stop2)
                                 (string<? (stop-name stop1)
                                           (stop-name stop2))))))

       (define min-lon (def:min-lon stops))
       (define max-lon (def:max-lon stops))
       (define min-lat (def:min-lat stops))
       (define max-lat (def:max-lat stops))

       <global-state>]

@subsection{Global State}

@itemlist[
 @item{@racket[global-state] is a @racket[web-cell] which keeps track of the current session's data}
 @item{it automatically tracks browser history (back/forth) and separate sessions}
 ]

@chunk[<global-state>
       <default-states>

       (define global-state
         (make-web-cell default-global-state))

       (define (set-global-state new-state)
         (web-cell-shadow global-state new-state))

       (define (get-global-state)
         (web-cell-ref global-state))]

@chunk[<default-states>
       (define default-stop-list-state
         (stop-list-state #f (list-layout "" min-lon max-lon min-lat max-lat 0) #t #f #f))

       (define default-stops-state
         (stops-state default-stop-list-state
                      default-stop-list-state))

       (define default-route-state
         (route-state "" "Bus" "" "" default-stop-list-state (set) "" '(data-missing stop-number)))

       (define default-food-state
         (food-state default-stop-list-state 10))

       (define default-global-state (web-state default-stops-state
                                               default-route-state
                                               default-food-state))]

@section{Formlet Infrastructure}

@section{Reusable Stop List Formlet}

Reused in every tab for stop selection. Constituents:

@itemlist[
 @item{@italic{stop-list-input}: the actual HTML form list}
 @item{@italic{filter-defs}: extracts the currently chosen filter settings from the form for saving in global state}
 @item{@italic{stop-list-formlet}: formlet glueing together the list and filter settings; state is saved in a compound state}
 ]

@chunk[<stop-list-input>
       (define (stop-list-input stops current-stop)
         (multiselect-input
          stops
          #:multiple? #f
          #:attributes `((size ,(->string (info 'web-stop-list-size))))
          #:display (lambda (stop)
                      (format "~a (~a / ~a)"
                              (stop-name stop)
                              (format-range (lon-range stop))
                              (format-range (lat-range stop))))
          #:selected? (lambda (stop)
                        (equal? stop current-stop))))]

@chunk[<filter-defs>
       (define (filter-defs state)
         (let* ([layout (stop-list-state-layout state)]
                [filter-layout
                 (list-layout (if (stop-list-state-use-name-filter? state)
                                  (list-layout-filter-expr layout)
                                  "")
                              (if (stop-list-state-use-lon-filter? state)
                                  (list-layout-min-lon layout)
                                  min-lon)
                              (if (stop-list-state-use-lon-filter? state)
                                  (list-layout-max-lon layout)
                                  max-lon)
                              (if (stop-list-state-use-lat-filter? state)
                                  (list-layout-min-lat layout)
                                  min-lat)
                              (if (stop-list-state-use-lat-filter? state)
                                  (list-layout-max-lat layout)
                                  max-lat)
                              0)])
           filter-layout))]

@chunk[<stop-list-formlet>
       <stop-list-input>

       <filter-defs>
       
       (define (stop-list-formlet state)
         (let* ([current-stop (stop-list-state-stop state)]
                [layout (stop-list-state-layout state)]
                [stops (filter-stops stops (filter-defs state))])
           (formlet
            (#%#
             (h2 ,(if current-stop
                      (stop-name current-stop)
                      "no stop selected"))
             (h3 ,(if current-stop
                      (format "(~a / ~a)"
                              (format-range (lon-range current-stop))
                              (format-range (lat-range current-stop)))
                      "-"))
             (div ,{(stop-list-input stops current-stop) . => . selected-stops})
             (p ,{(checkbox-input (stop-list-state-use-name-filter? state))
        . => . use-name-filter?}
                "Name filter "
                ,{(preset-text-input
                   (list-layout-filter-expr (stop-list-state-layout state)))
        . => . name-filter})

             (p ,{(checkbox-input (stop-list-state-use-lon-filter? state))
        . => . use-lon-filter?}
                "Longitude filter")
             (div
              "min. Lon.: "
              ,{(number-input (list-layout-min-lon layout) min-lon max-lon min-lon)
        . => . min-lon})
             (div
              "max. Lon.: "
              ,{(number-input (list-layout-max-lon layout) min-lon max-lon max-lon)
        . => . max-lon})

             (p ,{(checkbox-input (stop-list-state-use-lat-filter? state)) . => . use-lat-filter?}
                "Latitude filter")
             (div
              "min. Lat.: "
              ,{(number-input (list-layout-min-lat layout) min-lat max-lat min-lat)
        . => . min-lat})
             (div
              "max. Lat.: "
              ,{(number-input (list-layout-max-lat layout) min-lat max-lat max-lat)
        . => . max-lat}))
     
            (stop-list-state (if (not (null? selected-stops))
                                 (car selected-stops)
                                 #f)
                             (list-layout name-filter min-lon max-lon min-lat max-lat 0)
                             use-name-filter? use-lon-filter? use-lat-filter?))))]

@subsection{Formlet Parts}

@itemlist[
 @item{commonly reused formlet pieces}
 ]

@chunk[<formlet-parts>
       (define (checkbox-input checked?)
         (cross (pure (lambda (x) (and x #t)))
                (checkbox "" checked?)))

       (define (preset-text-input preset-value [attributes '()])
         (to-string (default #"" (text-input
                                  #:value preset-value
                                  #:attributes attributes))))

       (define (number-input preset min max preset-value [step 0.0000001])
         (~> (input #:type "number"
                    #:attributes
                    `((value ,(->string preset))
                      (min ,(->string min))
                      (max ,(->string max))
                      (step ,(->string step))))
             (default (string->bytes/utf-8 (->string preset-value)) _)
             to-string
             to-number))
       
       <stop-list-formlet>]

@subsection{State Data Handling}

@itemlist[
 @item{extract formlet state data from the HTTP requests}
 ]

@chunk[<bindings>
       (define (bindings request)
         (force (request-bindings/raw-promise request)))

       (define (has-bindings? request)
         (not (null? (bindings request))))

       (define (route-state-from-request request)
         (if (has-bindings? request)
             (formlet-process (route-formlet (web-state-route (get-global-state)))
                              request)
             (web-state-route (get-global-state))))

       (define (stops-state-from-request request)
         (if (has-bindings? request)
             (formlet-process (stop-formlet (web-state-stops (get-global-state)))
                              request)
             (web-state-stops (get-global-state))))

       (define (food-state-from-request request)
         (if (has-bindings? request)
             (formlet-process (food-formlet (web-state-food (get-global-state)))
                              request)
             (web-state-food (get-global-state))))]

@section{Tabbing}

@chunk[<tabbing>
       <top-level-responses>

       (define tab-info (vector (cons "Routes Between Stops" render-stop-info-page)
                                (cons "New Route Creation" render-route-edit-page)
                                (cons "Restaurant Finder" render-food-page)))

       (define (format-tab-header header)
         (format "~a" header))

       (define (tabbing tab-info selected-index embed/url)
         `(ul
           ,@(add-between (for/list ([index (in-naturals)]
                                     [tab tab-info])
                            `(li ([style "display:inline"])
                                 ,(if (= index selected-index)
                                      (format-tab-header (car tab))
                                      `(a ((href ,(embed/url (cdr tab))))
                                          ,(format-tab-header (car tab))))))
                          `(li ([style "display:inline"]) " | "))))]

@itemlist[
 @item{each tab corresponds to a servlet response from the web server}
 @item{the basic structure is always the same: create correct tab header and display top-level formlet}
 ]

@chunk[<top-level-responses>
       (define (create-stop-info-response state embed/url)
         (let ([index 0])
           (response/xexpr
            `(html
              (head (title "route21 - Routes Between Stops")
                    ,stylesheet-link)
              (body
               ,(tabbing tab-info index embed/url)
               ,@(formlet-display (stop-formlet state embed/url)))))))

       (define (create-route-edit-response state embed/url)
         (let ([index 1])
           (response/xexpr
            `(html
              (head (title "route21 - New Route Creation")
                    ,stylesheet-link)
              (body
               ,(tabbing tab-info index embed/url)
               ,@(formlet-display (route-formlet state embed/url)))))))

       (define (create-food-response state embed/url)
         (let ([index 2])
           (response/xexpr
            `(html
              (head (title "route21 - Restaurant Finder")
                    ,stylesheet-link)
              (body
               ,(tabbing tab-info 2 embed/url)
               ,@(formlet-display (food-formlet state embed/url)))))))]

@section{Routes for Stops}

@itemlist[
 @item{show two @italic{stop-list-formlet} inputs}
 @item{calculate routes to be shown from selected stops}
 @item{display routes in table}
 ]

@chunk[<stop-info>
       (define (stop-formlet state [embed/url (λ (x) "")])
         (let* ([state1 (stops-state-list1 state)]
                [state2 (stops-state-list2 state)])
           (formlet
            (#%#
             (fieldset
              (legend "Stop Selection")
              (form
               ([action ,(embed/url render-stop-info-page)])
               (div ([class "row"])
                    (div ([class "column"])
                         ,{(stop-list-formlet state1) . => . list-state1})
                    (div ([class "column"])
                         ,{(stop-list-formlet state2) . => . list-state2}))
               (p ,{(submit "Filter / Select") . => . submit})))
             (fieldset
              (legend "Routes for Selected Stops")
              ,(route-table state)))
            (stops-state list-state1 list-state2))))

       (define (render-stop-info-page request)
         (let* ([stops-state (stops-state-from-request request)]
                [response-generator (lambda (embed/url)
                                      (create-stop-info-response stops-state embed/url))])
           (set-global-state (struct-copy web-state
                                          (get-global-state)
                                          [stops stops-state]))
           (send/suspend/dispatch response-generator)))

       (define (routes-for-stops compound-stop1 compound-stop2)
         (if (and (and compound-stop1 compound-stop2)
                  (not (equal? compound-stop1 compound-stop2)))
             (let* ([stops1 (constituents compound-stop1)]
                    [stops2 (constituents compound-stop2)]
                    [routes (routes-for-all-stop-pairs provider stops1 stops2)])
               routes)
             null))
       
       <route-table>]

@subsection{Route Table Creation}

@chunk[<route-table>
       (define (route-table-entries routes)
         (for/list ([route routes])
           `(tr (td ,(route-type route))
                (td ,(route-number route))
                (td ,(route-start route))
                (td ,(route-end route)))))

       (define (route-table state)
         (let* ([stop1 (stop-list-state-stop (stops-state-list1 state))]
                [stop2 (stop-list-state-stop (stops-state-list2 state))]
                [routes (routes-for-stops stop1 stop2)]
                [route-entries (route-table-entries routes)])
           `(table
             (tr (th ([align "left"]) "Type")
                 (th ([align "left"]) "Number")
                 (th ([align "left"]) "Start")
                 (th ([align "left"]) "End"))
             ,@route-entries)))]

@section{Create New Route}

@chunk[<route-creation>
       (define (render-route-edit-page request)
         (let* ([state (route-state-from-request request)]
                [new-messages (process-route-submission state)]
                [new-state (struct-copy route-state state [messages new-messages])]
                [response-generator (λ (embed/url)
                                      (create-route-edit-response new-state embed/url))]
                [new-global-state (struct-copy web-state
                                               (get-global-state)
                                               [route new-state])])
           (set-global-state new-global-state)
           (send/suspend/dispatch response-generator)))

       (define (route-formlet state [embed/url (λ (x) "")])
         (let* ([current-stops (route-state-stops state)]
                [messages (route-state-messages state)])
           (formlet
            (#%#
             (form
              ([action ,(embed/url render-route-edit-page)])
              (fieldset
               (legend "Data for New Route")
               (div
                ([class "row"])
                "Number: "
                ,{(preset-text-input (route-state-number state)) . => . number}
                " Type: "
                ,{(radio-group '("Bus" "Tram")
                               #:checked? (λ (t) (equal? t (route-state-type state))))
        . => . type})
               (div
                ([class "row"])
                (div ([class "column"])
                     "Start: "
                     ,{(preset-text-input (route-state-start state)) . => . start})
                (div ([class "column"])
                     "End: "
                     ,{(preset-text-input (route-state-end state)) . => . end}))
               ,(if (contains? messages 'data-missing)
                    `(div ([class "row"])
                          (p "Please enter data for Number, Start and End."))
                    "")
               ,(if (contains? messages 'exists)
                    `(div ([class "row"])
                          (p "Route with this data already exists."))
                    ""))
              (fieldset
               (legend "Stops for New Route")
               (div
                ([class "row"])
                (div ([class "three-column-outer"])
                     (p ,{(stop-list-formlet (route-state-list state)) . => . list-state})
                     (p ,{(submit "Filter") . => . submit-filter})
                     ,(if (contains? messages 'stop-number)
                          `(div ([class "row"])
                                (p "Please select at least 2 stops."))
                          ""))
                (div ([class "three-column-inner"])
                     (p ,{(submit "Add Stop ->") . => . submit-add-stop})
                     (p ,{(submit "<- Remove Stop") . => . submit-remove-stop}))
                (div ([class "three-column-outer"])
                     ,{(stop-list-input current-stops #f) . => . selected-new-stops})))
              (p ,{(submit "Create New Route") . => . submit-create-route})))
            (let* ([submit-type (cond
                                  (submit-filter "filter")
                                  (submit-create-route "create-route")
                                  (submit-add-stop "add-stop")
                                  (submit-remove-stop "remove-stop"))]
                   [selected-stop (stop-list-state-stop list-state)]
                   [stops (case submit-type
                            [("create-route" "filter") current-stops]
                            [("add-stop") (if (and selected-stop
                                                   (not (set-member? current-stops selected-stop)))
                                              (set-add current-stops selected-stop)
                                              current-stops)]
                            [("remove-stop") (if (and selected-new-stops
                                                      (not (null? selected-new-stops)))
                                                 (set-remove current-stops
                                                             (first selected-new-stops))
                                                 current-stops)])])
              (route-state number type start end list-state stops submit-type messages)))))

       (define (process-route-submission state)
         (let* ([number (route-state-number state)]
                [type (route-state-type state)]
                [start (route-state-start state)]
                [end (route-state-end state)]
                [data (list number type start end)]
                [all-data-given? (for/and ([datum data])
                                   (non-empty-string? datum))]
                [new-route (route 0 number type start end)]
                [already-exists? (send provider route-exists? new-route)]
                [stops (route-state-stops state)]
                [stop-number-ok? (>= (set-count stops) 2)])
           (if (and all-data-given? stop-number-ok? (not already-exists?)
                    (equal? "create-route" (route-state-submit-type state)))
               (begin
                 (send provider insert-route new-route (set-map stops stop-id))
                 null)
               (filter (λ (x) (not (void? x)))
                       (list (unless all-data-given? 'data-missing)
                             (unless stop-number-ok? 'stop-number)
                             (when already-exists? 'exists))))))

       (define (render-food-page request)
         (let* ([state (food-state-from-request request)]
                [response-generator (λ (embed/url)
                                      (create-food-response state embed/url))]
                [new-global-state (struct-copy web-state
                                               (get-global-state)
                                               [food state])])
           (set-global-state new-global-state)
           (send/suspend/dispatch response-generator)))

       (define (food-table-entries food-data)
         (for/list ([datum food-data])
           (match-let ([(cons distance food) datum])
             `(tr (td ,(format "~am"(->string (->int (floor distance)))))
                  (td ,(food-name food))
                  (td (a ((href ,(food-website food))
                          (target "_blank"))
                         ,(food-website food)))))))

       (define (food-table lon lat distance)
         (let* ([foods (send provider food-at-place lon lat distance)]
                [food-entries (food-table-entries foods)]
                [table `(table
                         (tr (th ([align "left"]) "Distance")
                             (th ([align "left"]) "Name")
                             (th ([align "left"]) "Website"))
                         ,@food-entries)])
           table))]

@section{Restaurant Finder}

@chunk[<restaurant-finder>
       (define (food-formlet state [embed/url (λ (x) "")])
         (let* ([list-state (food-state-list state)]
                [current-stop (stop-list-state-stop (food-state-list state))]
                [current-distance (food-state-distance state)])
           (formlet
            (#%#
             (form
              ([action ,(embed/url render-food-page)])
              (fieldset
               (legend "Stop Selection")
               ,{(stop-list-formlet list-state) . => . list-state})
              (fieldset
               (legend "Distance Selection")
               (p "max. Restaurant distance (meters): "
                  ,{(number-input current-distance 0 999999 current-distance 1) . => . distance}))
              (p ,{(submit "Filter / Select") . => . submit})
              ,(if current-stop
                   `(fieldset
                     (legend ,(format "Restaurants within ~a meters of stop ~a" current-distance (stop-name current-stop)))
                     ,(food-table (stop-lon current-stop)
                                  (stop-lat current-stop)
                                  current-distance))
                   "")))
            (food-state list-state distance))))]

@section{Web Setup}

@chunk[<web-setup>
       (provide/contract (start (request? . -> . response?)))

       (define (start request)
         (render-stop-info-page request))

       (define stylesheet-link `(link ((rel "stylesheet")
                                       (href "/styles.css")
                                       (type "text/css"))))

       (define-runtime-path htdocs "htdocs")
              
       (serve/servlet
        start
        #:launch-browser? #f
        #:quit? #f
        #:listen-ip #f
        #:port 8021
        #:manager (create-timeout-manager #f
                                          (info 'web-timeout-seconds)
                                          (info 'web-timeout-seconds))
        #:extra-files-paths (list htdocs)
        #:servlet-path "/servlets/route21.rkt")]

@section{File Structure}

@chunk[<*>
       <requires>

       <module-data>
       <formlet-parts>
              
       <stop-info>
       <route-creation>
       <restaurant-finder>

       <tabbing>

       (define (contains? list x)
         (if (findf (λ (element) (equal? element x)) list)
             #t
             #f))

       <bindings>

       <web-setup>]

@subsection{Required Imports}

@chunk[<requires>
       (require racket)
       (require racket/format)
       (require anaphoric)
       (require threading)
       (require setup/getinfo)
       (require sugar/coerce)
       (require racket/runtime-path)
       (require web-server/http/bindings)
       (require web-server/formlets)
       (require web-server/formlets/input)
       (require web-server/formlets/lib)
       (require web-server/servlet)
       (require web-server/servlet-env)
       (require web-server/servlet/web-cells)
       (require web-server/managers/timeouts)
       (require (rename-in "data-defs.rkt"
                           (min-lon def:min-lon)
                           (max-lon def:max-lon)
                           (min-lat def:min-lat)
                           (max-lat def:max-lat)))
       (require "data-provider.rkt")
       (require "data-provider-factory.rkt")
       (require "list-layout.rkt")
       (require "web-states.rkt")
       (require "util.rkt")
       ]
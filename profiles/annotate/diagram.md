sequenceDiagram
actor user
participant user
participant annotation-app
participant annotation-ui
Note over user, annotation-app, annotation-ui: create annotation
user ->>annotation-app: load-page
user ->>annotation-ui: select text
user ->>annotation-ui: select annotation type


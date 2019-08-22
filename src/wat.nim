import asyncdispatch, nuuid, ormin, jester, json

importModel(DbBackend.sqlite, "wat_model")

var db {.global.} = open("wat.db", "", "", "")

let users = query:
  select users(uuid, fullname, email, created_at)
  produce json
echo users

routes:
  get "/":
    let users = query:
      select users(uuid, fullname, email, created_at)
      produce json

    echo users
    resp "see stdout"

runForever()

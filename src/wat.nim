import asyncdispatch, dotenv, easy_bcrypt, httpclient, nuuid, logging, options, os, ormin, jester, json, strformat

try: initDotEnv().overload
except: discard

import watPkg/mail
importModel(DbBackend.sqlite, "wat_model")

var db {.global.} = open("wat.db", "", "", "")
var logger = newConsoleLogger()
addHandler(logger)

type
  User* = object
    uuid*: string
    name*: string
    is_advertiser*: bool
    created_at*: string

  Campaign* = object
    uuid*: string
    creator*: string
    title*: string
    box_image_id*: string
    plaintext*: string
    target_url*: string
    created_at*: int
    updated_at*: Option[int]

proc getCurrentUser(r: Request): User =
  let
    authToken = r.cookies["auth_token"]
    userId = query:
      select tokens(creator)
      where token == ?authToken
      limit 1
    userData = query:
      select users(fullname, is_advertiser, created_at)
      where uuid == ? $userId
      limit 1

  result.uuid = userId
  result.name = userData.fullname
  result.is_advertiser = userData.is_advertiser == 1
  result.created_at = userData.created_at

router users:
  template protect(request: Request, body: untyped): untyped =
    try:
      discard request.cookies["auth_token"]
    except:
      halt Http403, "Permission denied"
    body
  get "/whoami":
    protect(request):
      resp Http200, $ %* request.getCurrentUser, "application/json"

  get "/activate":
    let tok = @"token"
    let uuid = query:
      select activation_tokens(user_id)
      where token == ?tok
      limit 1
    query:
      update activation_tokens(already_used = 1)
      where token == ?tok
    query:
      update users(activated = 1)
      where uuid == ?uuid
    let
      token = generateUUID()
      tokenID = generateUUID()
    query:
      insert tokens(
        uuid = ?tokenID,
        creator = ?uuid,
        token = ?token,
      )

    setCookie("auth_token", token)
    resp Http200, "Account verification successful, use the cookie auth_token as authentication in the future"

router ads:
  template protect(request: Request, body: untyped): untyped =
    try:
      discard request.cookies["auth_token"]
    except:
      halt Http403, "Permission denied"
      body

  get "/list":
    protect(request):
      let u = request.getCurrentUser
      let toReturn = query:
        select campaigns(uuid, title, box_image_id, plaintext, target_url, created_at, updated_at)
        where creator == ?u.uuid
        produce json
      resp Http200, $toReturn, "applicaton/json"

  post "/create":
    protect(request):
      let u = request.getCurrentUser
      let j = request.body.parseJson
      let hc = newAsyncHttpClient()
      var camp = Campaign()
      camp.uuid = generateUUID()
      camp.creator = u.uuid
      camp.title = j["title"].getStr
      camp.box_image_id = j["box_image_id"].getStr
      camp.plaintext = j["plaintext"].getStr
      camp.target_url = j["target_url"].getStr

      let resp = await hc.get(camp.target_url)
      if resp.status != $Http200:
        halt Http400, "target_url must return HTTP 200"

      camp.created_at = query:
        insert campaigns(
          uuid = ?camp.uuid,
          creator = ?camp.creator,
          title = ?camp.title,
          box_image_id = ?camp.box_image_id,
          plaintext = ?camp.plaintext,
          target_url = ?camp.target_url,
        )
        returning created_at

      resp Http200, $ %* camp, "application/json"

routes:
  error Http404:
    resp Http404, "not found"
  error Http400:
    resp Http400, "bad request"
  error Exception:
    warn getCurrentException().name
    warn getCurrentExceptionMsg()
    resp Http500, "oops, a problem happened :(", "text/plain"

  extend users, "/api/users"
  extend ads, "/api/ads"

  post "/register":
    proc get(fd: MultiData, key: string): string =
      fd[key].body
    let
      uuid = generateUUID()
      fullname = request.formData.get("fullname")
      email = request.formData.get("email")
      password = request.formData.get("password")
      hashedPw = $hashPw(password, genSalt(12))

    query:
      insert users(
        uuid = ?uuid,
        fullname = ?fullname,
        email = ?email,
        pw_hash = ?hashedPw,
        is_advertiser = 0,
      )

    let actToken = generateUUID()

    query:
      insert activation_tokens(
        token = ?actToken,
        user_id = ?uuid,
      )

    asyncCheck sendActivationEmail(fmt"{fullname} <{email}>", actToken)

    resp uuid

settings:
  port = getEnv("PORT").parseInt.Port

import asyncdispatch, easy_bcrypt, httpclient, nuuid, logging, options, ormin, jester, json

importModel(DbBackend.sqlite, "wat_model")

var db {.global.} = open("wat.db", "", "", "")

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
  before:
    try:
      discard request.cookies["auth_token"]
    except:
      halt Http403, "Permission denied"
  get "/whoami":
    resp Http200, $ %* request.getCurrentUser, "application/json"

let hc = newAsyncHttpClient()

router ads:
  before:
    try:
      discard request.cookies["auth_token"]
    except:
      halt Http403, "Permission denied"

  get "/list":
    let u = request.getCurrentUser
    let toReturn = query:
      select campaigns(uuid, title, box_image_id, plaintext, target_url, created_at, updated_at)
      where creator == ?u.uuid
      produce json
    resp Http200, $toReturn, "applicaton/json"

  post "/create":
    let u = request.getCurrentUser
    let j = request.body.parseJson
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
  # error Http404:
  #   halt Http404, "not found"
  # error Http400:
  #   halt Http400, "bad request"
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
      token = generateUUID()
      tokenID = generateUUID()

    query:
      insert users(
        uuid = ?uuid,
        fullname = ?fullname,
        email = ?email,
        pw_hash = ?hashedPw,
        is_advertiser = 0,
      )
    query:
      insert tokens(
        uuid = ?tokenID,
        creator = ?uuid,
        token = ?token,
      )

    setCookie("auth_token", token)
    resp uuid


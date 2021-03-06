import asyncdispatch, oids, options

from bcrypt import hash, compare, genSalt
import sam

from ../model/user
  import User, findByEmail, findById, findByUsername, insert, initUser, update
from ../util/mapping import mapNonNil
from ../util/future import failed


type
  UpdateUser* = ref object
    email*: string
    username*: string
    password*: string
    bio*: string
    image*: string

  UnmatchingPasswordError* = object of Exception

proc readFromJson*(s: string, t: typedesc[UpdateUser]): UpdateUser =
  result.new

  loads(result, s)

proc checkPassword(receivedPassword, storedHash, salt: string): bool =
  let hashedPw = hash(receivedPassword, salt)

  compare(hashedPw, storedHash)

proc login*(email, password: string): Future[User] {.async.} =
  let userFut = findByEmail(email)

  yield userFut

  if (userFut.failed):
    return await userFut
  elif (not checkPassword(password, userFut.read().hash, userFut.read().salt)):
    return await failed[User](newException(UnmatchingPasswordError, "Passwords do not match!"))
  else:
    return await userFut

proc getById*(id: Oid): Future[User] =
  return findById(id)

proc getByUsername*(username: string): Future[User] =
  return findByUsername(username)

proc generatePassword(password: string): (string, string) =
  let salt = genSalt(10)

  (hash(password, salt), salt)

proc register*(email, username, password: string): Future[User] =
  let user = initUser()

  user.email = email
  user.username = username
  (user.hash, user.salt) = generatePassword(password)

  return insert(user)

proc update*(u: User): Future[User] =
  return user.update(u)

proc updateWith*(barebones: UpdateUser, original: User): Future[User] =
  mapNonNil(
    source = barebones,
    dest   = original,
    fields = ["username", "email", "bio", "image"]
  )

  if barebones.password != nil:
    (original.hash, original.salt) = generatePassword(barebones.password)

  return update(original)

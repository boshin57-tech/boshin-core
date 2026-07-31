(() => {
  var __defProp = Object.defineProperty;
  var __typeError = (msg) => {
    throw TypeError(msg);
  };
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
  var __accessCheck = (obj, member, msg) => member.has(obj) || __typeError("Cannot " + msg);
  var __privateGet = (obj, member, getter) => (__accessCheck(obj, member, "read from private field"), getter ? getter.call(obj) : member.get(obj));
  var __privateAdd = (obj, member, value) => member.has(obj) ? __typeError("Cannot add the same private member more than once") : member instanceof WeakSet ? member.add(obj) : member.set(obj, value);
  var __privateSet = (obj, member, value, setter) => (__accessCheck(obj, member, "write to private field"), setter ? setter.call(obj, value) : member.set(obj, value), value);
  var __privateMethod = (obj, member, method) => (__accessCheck(obj, member, "access private method"), method);

  // node_modules/@mysten/bcs/dist/uleb.mjs
  function ulebEncode(num) {
    let bigNum = BigInt(num);
    const arr = [];
    let len = 0;
    if (bigNum === 0n) return [0];
    while (bigNum > 0) {
      arr[len] = Number(bigNum & 127n);
      bigNum >>= 7n;
      if (bigNum > 0n) arr[len] |= 128;
      len += 1;
    }
    return arr;
  }
  function ulebDecode(arr) {
    let total = 0n;
    let shift = 0n;
    let len = 0;
    while (true) {
      if (len >= arr.length) throw new Error("ULEB decode error: buffer overflow");
      const byte = arr[len];
      len += 1;
      total += BigInt(byte & 127) << shift;
      if ((byte & 128) === 0) break;
      shift += 7n;
    }
    if (total > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("ULEB decode error: value exceeds MAX_SAFE_INTEGER");
    return {
      value: Number(total),
      length: len
    };
  }

  // node_modules/@mysten/bcs/dist/reader.mjs
  var BcsReader = class {
    /**
    * @param {Uint8Array} data Data to use as a buffer.
    */
    constructor(data) {
      this.bytePosition = 0;
      this.dataView = new DataView(data.buffer, data.byteOffset, data.byteLength);
    }
    /**
    * Shift current cursor position by `bytes`.
    *
    * @param {Number} bytes Number of bytes to
    * @returns {this} Self for possible chaining.
    */
    shift(bytes) {
      this.bytePosition += bytes;
      return this;
    }
    /**
    * Read U8 value from the buffer and shift cursor by 1.
    * @returns
    */
    read8() {
      const value = this.dataView.getUint8(this.bytePosition);
      this.shift(1);
      return value;
    }
    /**
    * Read U16 value from the buffer and shift cursor by 2.
    * @returns
    */
    read16() {
      const value = this.dataView.getUint16(this.bytePosition, true);
      this.shift(2);
      return value;
    }
    /**
    * Read U32 value from the buffer and shift cursor by 4.
    * @returns
    */
    read32() {
      const value = this.dataView.getUint32(this.bytePosition, true);
      this.shift(4);
      return value;
    }
    /**
    * Read U64 value from the buffer and shift cursor by 8.
    * @returns
    */
    read64() {
      const value1 = this.read32();
      const result = this.read32().toString(16) + value1.toString(16).padStart(8, "0");
      return BigInt("0x" + result).toString(10);
    }
    /**
    * Read U128 value from the buffer and shift cursor by 16.
    */
    read128() {
      const value1 = BigInt(this.read64());
      const result = BigInt(this.read64()).toString(16) + value1.toString(16).padStart(16, "0");
      return BigInt("0x" + result).toString(10);
    }
    /**
    * Read U128 value from the buffer and shift cursor by 32.
    * @returns
    */
    read256() {
      const value1 = BigInt(this.read128());
      const result = BigInt(this.read128()).toString(16) + value1.toString(16).padStart(32, "0");
      return BigInt("0x" + result).toString(10);
    }
    /**
    * Read `num` number of bytes from the buffer and shift cursor by `num`.
    * @param num Number of bytes to read.
    */
    readBytes(num) {
      const start = this.bytePosition + this.dataView.byteOffset;
      const value = new Uint8Array(this.dataView.buffer, start, num);
      this.shift(num);
      return value;
    }
    /**
    * Read ULEB value - an integer of varying size. Used for enum indexes and
    * vector lengths.
    * @returns {Number} The ULEB value.
    */
    readULEB() {
      const start = this.bytePosition + this.dataView.byteOffset;
      const { value, length } = ulebDecode(new Uint8Array(this.dataView.buffer, start));
      this.shift(length);
      return value;
    }
    /**
    * Read a BCS vector: read a length and then apply function `cb` X times
    * where X is the length of the vector, defined as ULEB in BCS bytes.
    * @param cb Callback to process elements of vector.
    * @returns {Array<Any>} Array of the resulting values, returned by callback.
    */
    readVec(cb) {
      const length = this.readULEB();
      const result = [];
      for (let i = 0; i < length; i++) result.push(cb(this, i, length));
      return result;
    }
  };

  // node_modules/@scure/base/index.js
  function isBytes(a) {
    return a instanceof Uint8Array || ArrayBuffer.isView(a) && a.constructor.name === "Uint8Array" && "BYTES_PER_ELEMENT" in a && a.BYTES_PER_ELEMENT === 1;
  }
  function isArrayOf(isString, arr) {
    if (!Array.isArray(arr))
      return false;
    if (arr.length === 0)
      return true;
    if (isString) {
      return arr.every((item) => typeof item === "string");
    } else {
      return arr.every((item) => Number.isSafeInteger(item));
    }
  }
  function astr(label, input) {
    if (typeof input !== "string")
      throw new TypeError(`${label}: string expected`);
    return true;
  }
  function anumber(n) {
    if (typeof n !== "number")
      throw new TypeError(`number expected, got ${typeof n}`);
    if (!Number.isSafeInteger(n))
      throw new RangeError(`invalid integer: ${n}`);
  }
  function aArr(input) {
    if (!Array.isArray(input))
      throw new TypeError("array expected");
  }
  function astrArr(label, input) {
    if (!isArrayOf(true, input))
      throw new TypeError(`${label}: array of strings expected`);
  }
  function anumArr(label, input) {
    if (!isArrayOf(false, input))
      throw new TypeError(`${label}: array of numbers expected`);
  }
  // @__NO_SIDE_EFFECTS__
  function chain(...args) {
    const id = (a) => a;
    const wrap = (a, b) => (c) => a(b(c));
    const encode = args.map((x) => x.encode).reduceRight(wrap, id);
    const decode = args.map((x) => x.decode).reduce(wrap, id);
    return { encode, decode };
  }
  // @__NO_SIDE_EFFECTS__
  function alphabet(letters) {
    const lettersA = typeof letters === "string" ? letters.split("") : letters;
    const len = lettersA.length;
    astrArr("alphabet", lettersA);
    const indexes = new Map(lettersA.map((l, i) => [l, i]));
    return {
      encode: (digits) => {
        aArr(digits);
        return digits.map((i) => {
          if (!Number.isSafeInteger(i) || i < 0 || i >= len)
            throw new Error(`alphabet.encode: digit index outside alphabet "${i}". Allowed: ${letters}`);
          return lettersA[i];
        });
      },
      decode: (input) => {
        aArr(input);
        return input.map((letter) => {
          astr("alphabet.decode", letter);
          const i = indexes.get(letter);
          if (i === void 0)
            throw new Error(`Unknown letter: "${letter}". Allowed: ${letters}`);
          return i;
        });
      }
    };
  }
  // @__NO_SIDE_EFFECTS__
  function join(separator = "") {
    astr("join", separator);
    return {
      encode: (from) => {
        astrArr("join.decode", from);
        return from.join(separator);
      },
      decode: (to) => {
        astr("join.decode", to);
        return to.split(separator);
      }
    };
  }
  function convertRadix(data, from, to) {
    if (from < 2)
      throw new RangeError(`convertRadix: invalid from=${from}, base cannot be less than 2`);
    if (to < 2)
      throw new RangeError(`convertRadix: invalid to=${to}, base cannot be less than 2`);
    aArr(data);
    if (!data.length)
      return [];
    let pos = 0;
    const res = [];
    const digits = Array.from(data, (d) => {
      anumber(d);
      if (d < 0 || d >= from)
        throw new Error(`invalid integer: ${d}`);
      return d;
    });
    const dlen = digits.length;
    while (true) {
      let carry = 0;
      let done = true;
      for (let i = pos; i < dlen; i++) {
        const digit = digits[i];
        const fromCarry = from * carry;
        const digitBase = fromCarry + digit;
        if (!Number.isSafeInteger(digitBase) || fromCarry / from !== carry || digitBase - digit !== fromCarry) {
          throw new Error("convertRadix: carry overflow");
        }
        const div = digitBase / to;
        carry = digitBase % to;
        const rounded = Math.floor(div);
        digits[i] = rounded;
        if (!Number.isSafeInteger(rounded) || rounded * to + carry !== digitBase)
          throw new Error("convertRadix: carry overflow");
        if (!done)
          continue;
        else if (!rounded)
          pos = i;
        else
          done = false;
      }
      res.push(carry);
      if (done)
        break;
    }
    for (let i = 0; i < data.length - 1 && data[i] === 0; i++)
      res.push(0);
    return res.reverse();
  }
  // @__NO_SIDE_EFFECTS__
  function radix(num) {
    anumber(num);
    const _256 = 2 ** 8;
    return {
      encode: (bytes) => {
        if (!isBytes(bytes))
          throw new TypeError("radix.encode input should be Uint8Array");
        return convertRadix(Array.from(bytes), _256, num);
      },
      decode: (digits) => {
        anumArr("radix.decode", digits);
        return Uint8Array.from(convertRadix(digits, num, _256));
      }
    };
  }
  var genBase58 = /* @__NO_SIDE_EFFECTS__ */ (abc) => /* @__PURE__ */ chain(/* @__PURE__ */ radix(58), /* @__PURE__ */ alphabet(abc), /* @__PURE__ */ join(""));
  var base58 = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ genBase58("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"));

  // node_modules/@mysten/utils/dist/b58.mjs
  var toBase58 = (buffer) => base58.encode(buffer);
  var fromBase58 = (str) => base58.decode(str);

  // node_modules/@mysten/utils/dist/b64.mjs
  function fromBase64(base64String2) {
    return Uint8Array.from(atob(base64String2), (char) => char.charCodeAt(0));
  }
  var CHUNK_SIZE = 8192;
  function toBase64(bytes) {
    if (bytes.length < CHUNK_SIZE) return btoa(String.fromCharCode(...bytes));
    let output = "";
    for (var i = 0; i < bytes.length; i += CHUNK_SIZE) {
      const chunk = bytes.slice(i, i + CHUNK_SIZE);
      output += String.fromCharCode(...chunk);
    }
    return btoa(output);
  }

  // node_modules/@mysten/utils/dist/hex.mjs
  function fromHex(hexStr) {
    const normalized = hexStr.startsWith("0x") ? hexStr.slice(2) : hexStr;
    const padded = normalized.length % 2 === 0 ? normalized : `0${normalized}`;
    const intArr = padded.match(/[0-9a-fA-F]{2}/g)?.map((byte) => parseInt(byte, 16)) ?? [];
    if (intArr.length !== padded.length / 2) throw new Error(`Invalid hex string ${hexStr}`);
    return Uint8Array.from(intArr);
  }
  function toHex(bytes) {
    return bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, "0"), "");
  }

  // node_modules/@mysten/bcs/dist/utils.mjs
  function encodeStr(data, encoding) {
    switch (encoding) {
      case "base58":
        return toBase58(data);
      case "base64":
        return toBase64(data);
      case "hex":
        return toHex(data);
      default:
        throw new Error("Unsupported encoding, supported values are: base64, hex");
    }
  }
  function splitGenericParameters(str, genericSeparators = ["<", ">"]) {
    const [left, right] = genericSeparators;
    const tok = [];
    let word = "";
    let nestedAngleBrackets = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str[i];
      if (char === left) nestedAngleBrackets++;
      if (char === right) nestedAngleBrackets--;
      if (nestedAngleBrackets === 0 && char === ",") {
        tok.push(word.trim());
        word = "";
        continue;
      }
      word += char;
    }
    tok.push(word.trim());
    return tok;
  }

  // node_modules/@mysten/bcs/dist/writer.mjs
  var BcsWriter = class {
    constructor({ initialSize = 1024, maxSize = Infinity, allocateSize = 1024 } = {}) {
      this.bytePosition = 0;
      this.size = initialSize;
      this.maxSize = maxSize;
      this.allocateSize = allocateSize;
      this.dataView = new DataView(new ArrayBuffer(initialSize));
    }
    ensureSizeOrGrow(bytes) {
      const requiredSize = this.bytePosition + bytes;
      if (requiredSize > this.size) {
        const nextSize = Math.min(this.maxSize, Math.max(this.size + requiredSize, this.size + this.allocateSize));
        if (requiredSize > nextSize) throw new Error(`Attempting to serialize to BCS, but buffer does not have enough size. Allocated size: ${this.size}, Max size: ${this.maxSize}, Required size: ${requiredSize}`);
        this.size = nextSize;
        const nextBuffer = new ArrayBuffer(this.size);
        new Uint8Array(nextBuffer).set(new Uint8Array(this.dataView.buffer));
        this.dataView = new DataView(nextBuffer);
      }
    }
    /**
    * Shift current cursor position by `bytes`.
    *
    * @param {Number} bytes Number of bytes to
    * @returns {this} Self for possible chaining.
    */
    shift(bytes) {
      this.bytePosition += bytes;
      return this;
    }
    /**
    * Write a U8 value into a buffer and shift cursor position by 1.
    * @param {Number} value Value to write.
    * @returns {this}
    */
    write8(value) {
      this.ensureSizeOrGrow(1);
      this.dataView.setUint8(this.bytePosition, Number(value));
      return this.shift(1);
    }
    /**
    * Write a U8 value into a buffer and shift cursor position by 1.
    * @param {Number} value Value to write.
    * @returns {this}
    */
    writeBytes(bytes) {
      this.ensureSizeOrGrow(bytes.length);
      for (let i = 0; i < bytes.length; i++) this.dataView.setUint8(this.bytePosition + i, bytes[i]);
      return this.shift(bytes.length);
    }
    /**
    * Write a U16 value into a buffer and shift cursor position by 2.
    * @param {Number} value Value to write.
    * @returns {this}
    */
    write16(value) {
      this.ensureSizeOrGrow(2);
      this.dataView.setUint16(this.bytePosition, Number(value), true);
      return this.shift(2);
    }
    /**
    * Write a U32 value into a buffer and shift cursor position by 4.
    * @param {Number} value Value to write.
    * @returns {this}
    */
    write32(value) {
      this.ensureSizeOrGrow(4);
      this.dataView.setUint32(this.bytePosition, Number(value), true);
      return this.shift(4);
    }
    /**
    * Write a U64 value into a buffer and shift cursor position by 8.
    * @param {bigint} value Value to write.
    * @returns {this}
    */
    write64(value) {
      toLittleEndian(BigInt(value), 8).forEach((el) => this.write8(el));
      return this;
    }
    /**
    * Write a U128 value into a buffer and shift cursor position by 16.
    *
    * @param {bigint} value Value to write.
    * @returns {this}
    */
    write128(value) {
      toLittleEndian(BigInt(value), 16).forEach((el) => this.write8(el));
      return this;
    }
    /**
    * Write a U256 value into a buffer and shift cursor position by 16.
    *
    * @param {bigint} value Value to write.
    * @returns {this}
    */
    write256(value) {
      toLittleEndian(BigInt(value), 32).forEach((el) => this.write8(el));
      return this;
    }
    /**
    * Write a ULEB value into a buffer and shift cursor position by number of bytes
    * written.
    * @param {Number} value Value to write.
    * @returns {this}
    */
    writeULEB(value) {
      ulebEncode(value).forEach((el) => this.write8(el));
      return this;
    }
    /**
    * Write a vector into a buffer by first writing the vector length and then calling
    * a callback on each passed value.
    *
    * @param {Array<Any>} vector Array of elements to write.
    * @param {WriteVecCb} cb Callback to call on each element of the vector.
    * @returns {this}
    */
    writeVec(vector2, cb) {
      this.writeULEB(vector2.length);
      Array.from(vector2).forEach((el, i) => cb(this, el, i, vector2.length));
      return this;
    }
    /**
    * Adds support for iterations over the object.
    * @returns {Uint8Array}
    */
    *[Symbol.iterator]() {
      for (let i = 0; i < this.bytePosition; i++) yield this.dataView.getUint8(i);
      return this.toBytes();
    }
    /**
    * Get underlying buffer taking only value bytes (in case initial buffer size was bigger).
    * @returns {Uint8Array} Resulting bcs.
    */
    toBytes() {
      return new Uint8Array(this.dataView.buffer.slice(0, this.bytePosition));
    }
    /**
    * Represent data as 'hex' or 'base64'
    * @param encoding Encoding to use: 'base64' or 'hex'
    */
    toString(encoding) {
      return encodeStr(this.toBytes(), encoding);
    }
  };
  function toLittleEndian(bigint, size) {
    const result = new Uint8Array(size);
    let i = 0;
    while (bigint > 0) {
      result[i] = Number(bigint % BigInt(256));
      bigint = bigint / BigInt(256);
      i += 1;
    }
    return result;
  }

  // node_modules/@mysten/bcs/dist/bcs-type.mjs
  var _write, _serialize, _a;
  var BcsType = (_a = class {
    constructor(options) {
      __privateAdd(this, _write);
      __privateAdd(this, _serialize);
      this.name = options.name;
      this.read = options.read;
      this.serializedSize = options.serializedSize ?? (() => null);
      __privateSet(this, _write, options.write);
      __privateSet(this, _serialize, options.serialize ?? ((value, options$1) => {
        const writer = new BcsWriter({
          initialSize: this.serializedSize(value) ?? void 0,
          ...options$1
        });
        __privateGet(this, _write).call(this, value, writer);
        return writer.toBytes();
      }));
      this.validate = options.validate ?? (() => {
      });
    }
    write(value, writer) {
      this.validate(value);
      __privateGet(this, _write).call(this, value, writer);
    }
    serialize(value, options) {
      this.validate(value);
      return new SerializedBcs(this, __privateGet(this, _serialize).call(this, value, options));
    }
    parse(bytes) {
      const reader = new BcsReader(bytes);
      return this.read(reader);
    }
    fromHex(hex) {
      return this.parse(fromHex(hex));
    }
    fromBase58(b64) {
      return this.parse(fromBase58(b64));
    }
    fromBase64(b64) {
      return this.parse(fromBase64(b64));
    }
    transform({ name, input, output, validate }) {
      return new _a({
        name: name ?? this.name,
        read: (reader) => output ? output(this.read(reader)) : this.read(reader),
        write: (value, writer) => __privateGet(this, _write).call(this, input ? input(value) : value, writer),
        serializedSize: (value) => this.serializedSize(input ? input(value) : value),
        serialize: (value, options) => __privateGet(this, _serialize).call(this, input ? input(value) : value, options),
        validate: (value) => {
          validate?.(value);
          this.validate(input ? input(value) : value);
        }
      });
    }
  }, _write = new WeakMap(), _serialize = new WeakMap(), _a);
  var SERIALIZED_BCS_BRAND = /* @__PURE__ */ Symbol.for("@mysten/serialized-bcs");
  var _schema, _bytes, _a2;
  var SerializedBcs = (_a2 = class {
    constructor(schema, bytes) {
      __privateAdd(this, _schema);
      __privateAdd(this, _bytes);
      __privateSet(this, _schema, schema);
      __privateSet(this, _bytes, bytes);
    }
    get [SERIALIZED_BCS_BRAND]() {
      return true;
    }
    toBytes() {
      return __privateGet(this, _bytes);
    }
    toHex() {
      return toHex(__privateGet(this, _bytes));
    }
    toBase64() {
      return toBase64(__privateGet(this, _bytes));
    }
    toBase58() {
      return toBase58(__privateGet(this, _bytes));
    }
    parse() {
      return __privateGet(this, _schema).parse(__privateGet(this, _bytes));
    }
  }, _schema = new WeakMap(), _bytes = new WeakMap(), _a2);
  function fixedSizeBcsType({ size, ...options }) {
    return new BcsType({
      ...options,
      serializedSize: () => size
    });
  }
  function uIntBcsType({ readMethod, writeMethod, ...options }) {
    return fixedSizeBcsType({
      ...options,
      read: (reader) => reader[readMethod](),
      write: (value, writer) => writer[writeMethod](value),
      validate: (value) => {
        if (value < 0 || value > options.maxValue) throw new TypeError(`Invalid ${options.name} value: ${value}. Expected value in range 0-${options.maxValue}`);
        options.validate?.(value);
      }
    });
  }
  function bigUIntBcsType({ readMethod, writeMethod, ...options }) {
    return fixedSizeBcsType({
      ...options,
      read: (reader) => reader[readMethod](),
      write: (value, writer) => writer[writeMethod](BigInt(value)),
      validate: (val) => {
        const value = BigInt(val);
        if (value < 0 || value > options.maxValue) throw new TypeError(`Invalid ${options.name} value: ${value}. Expected value in range 0-${options.maxValue}`);
        options.validate?.(value);
      }
    });
  }
  function dynamicSizeBcsType({ serialize, ...options }) {
    const type = new BcsType({
      ...options,
      serialize,
      write: (value, writer) => {
        for (const byte of type.serialize(value).toBytes()) writer.write8(byte);
      }
    });
    return type;
  }
  function stringLikeBcsType({ toBytes, fromBytes, ...options }) {
    return new BcsType({
      ...options,
      read: (reader) => {
        const length = reader.readULEB();
        return fromBytes(reader.readBytes(length));
      },
      write: (hex, writer) => {
        const bytes = toBytes(hex);
        writer.writeULEB(bytes.length);
        for (let i = 0; i < bytes.length; i++) writer.write8(bytes[i]);
      },
      serialize: (value) => {
        const bytes = toBytes(value);
        const size = ulebEncode(bytes.length);
        const result = new Uint8Array(size.length + bytes.length);
        result.set(size, 0);
        result.set(bytes, size.length);
        return result;
      },
      validate: (value) => {
        if (typeof value !== "string") throw new TypeError(`Invalid ${options.name} value: ${value}. Expected string`);
        options.validate?.(value);
      }
    });
  }
  function lazyBcsType(cb) {
    let lazyType = null;
    function getType() {
      if (!lazyType) lazyType = cb();
      return lazyType;
    }
    return new BcsType({
      name: "lazy",
      read: (data) => getType().read(data),
      serializedSize: (value) => getType().serializedSize(value),
      write: (value, writer) => getType().write(value, writer),
      serialize: (value, options) => getType().serialize(value, options).toBytes()
    });
  }
  var BcsStruct = class extends BcsType {
    constructor({ name, fields, ...options }) {
      const canonicalOrder = Object.entries(fields);
      super({
        name,
        serializedSize: (values) => {
          let total = 0;
          for (const [field, type] of canonicalOrder) {
            const size = type.serializedSize(values[field]);
            if (size == null) return null;
            total += size;
          }
          return total;
        },
        read: (reader) => {
          const result = {};
          for (const [field, type] of canonicalOrder) result[field] = type.read(reader);
          return result;
        },
        write: (value, writer) => {
          for (const [field, type] of canonicalOrder) type.write(value[field], writer);
        },
        ...options,
        validate: (value) => {
          options?.validate?.(value);
          if (typeof value !== "object" || value == null) throw new TypeError(`Expected object, found ${typeof value}`);
        }
      });
    }
  };
  var BcsEnum = class extends BcsType {
    constructor({ fields, ...options }) {
      const canonicalOrder = Object.entries(fields);
      super({
        read: (reader) => {
          const index = reader.readULEB();
          const enumEntry = canonicalOrder[index];
          if (!enumEntry) throw new TypeError(`Unknown value ${index} for enum ${options.name}`);
          const [kind, type] = enumEntry;
          return {
            [kind]: type?.read(reader) ?? true,
            $kind: kind
          };
        },
        write: (value, writer) => {
          const [name, val] = Object.entries(value).filter(([name$1]) => Object.hasOwn(fields, name$1))[0];
          for (let i = 0; i < canonicalOrder.length; i++) {
            const [optionName, optionType] = canonicalOrder[i];
            if (optionName === name) {
              writer.writeULEB(i);
              optionType?.write(val, writer);
              return;
            }
          }
        },
        ...options,
        validate: (value) => {
          options?.validate?.(value);
          if (typeof value !== "object" || value == null) throw new TypeError(`Expected object, found ${typeof value}`);
          const keys = Object.keys(value).filter((k) => value[k] !== void 0 && Object.hasOwn(fields, k));
          if (keys.length !== 1) throw new TypeError(`Expected object with one key, but found ${keys.length} for type ${options.name}}`);
          const [variant] = keys;
          if (!Object.hasOwn(fields, variant)) throw new TypeError(`Invalid enum variant ${variant}`);
        }
      });
    }
  };
  var BcsTuple = class extends BcsType {
    constructor({ fields, name, ...options }) {
      super({
        name: name ?? `(${fields.map((t) => t.name).join(", ")})`,
        serializedSize: (values) => {
          let total = 0;
          for (let i = 0; i < fields.length; i++) {
            const size = fields[i].serializedSize(values[i]);
            if (size == null) return null;
            total += size;
          }
          return total;
        },
        read: (reader) => {
          const result = [];
          for (const field of fields) result.push(field.read(reader));
          return result;
        },
        write: (value, writer) => {
          for (let i = 0; i < fields.length; i++) fields[i].write(value[i], writer);
        },
        ...options,
        validate: (value) => {
          options?.validate?.(value);
          if (!Array.isArray(value)) throw new TypeError(`Expected array, found ${typeof value}`);
          if (value.length !== fields.length) throw new TypeError(`Expected array of length ${fields.length}, found ${value.length}`);
        }
      });
    }
  };

  // node_modules/@mysten/bcs/dist/bcs.mjs
  function fixedArray(size, type, options) {
    return new BcsType({
      read: (reader) => {
        const result = new Array(size);
        for (let i = 0; i < size; i++) result[i] = type.read(reader);
        return result;
      },
      write: (value, writer) => {
        for (const item of value) type.write(item, writer);
      },
      ...options,
      name: options?.name ?? `${type.name}[${size}]`,
      validate: (value) => {
        options?.validate?.(value);
        if (!value || typeof value !== "object" || !("length" in value)) throw new TypeError(`Expected array, found ${typeof value}`);
        if (value.length !== size) throw new TypeError(`Expected array of length ${size}, found ${value.length}`);
      }
    });
  }
  function option(type) {
    return bcs.enum(`Option<${type.name}>`, {
      None: null,
      Some: type
    }).transform({
      input: (value) => {
        if (value == null) return { None: true };
        return { Some: value };
      },
      output: (value) => {
        if (value.$kind === "Some") return value.Some;
        return null;
      }
    });
  }
  function vector(type, options) {
    return new BcsType({
      read: (reader) => {
        const length = reader.readULEB();
        const result = new Array(length);
        for (let i = 0; i < length; i++) result[i] = type.read(reader);
        return result;
      },
      write: (value, writer) => {
        writer.writeULEB(value.length);
        for (const item of value) type.write(item, writer);
      },
      ...options,
      name: options?.name ?? `vector<${type.name}>`,
      validate: (value) => {
        options?.validate?.(value);
        if (!value || typeof value !== "object" || !("length" in value)) throw new TypeError(`Expected array, found ${typeof value}`);
      }
    });
  }
  function compareBcsBytes(a, b) {
    for (let i = 0; i < Math.min(a.length, b.length); i++) if (a[i] !== b[i]) return a[i] - b[i];
    return a.length - b.length;
  }
  function map(keyType, valueType) {
    return new BcsType({
      name: `Map<${keyType.name}, ${valueType.name}>`,
      read: (reader) => {
        const length = reader.readULEB();
        const result = /* @__PURE__ */ new Map();
        for (let i = 0; i < length; i++) result.set(keyType.read(reader), valueType.read(reader));
        return result;
      },
      write: (value, writer) => {
        const entries = [...value.entries()].map(([key, val]) => [keyType.serialize(key).toBytes(), val]);
        entries.sort(([a], [b]) => compareBcsBytes(a, b));
        writer.writeULEB(entries.length);
        for (const [keyBytes, val] of entries) {
          writer.writeBytes(keyBytes);
          valueType.write(val, writer);
        }
      }
    });
  }
  var bcs = {
    u8(options) {
      return uIntBcsType({
        readMethod: "read8",
        writeMethod: "write8",
        size: 1,
        maxValue: 2 ** 8 - 1,
        ...options,
        name: options?.name ?? "u8"
      });
    },
    u16(options) {
      return uIntBcsType({
        readMethod: "read16",
        writeMethod: "write16",
        size: 2,
        maxValue: 2 ** 16 - 1,
        ...options,
        name: options?.name ?? "u16"
      });
    },
    u32(options) {
      return uIntBcsType({
        readMethod: "read32",
        writeMethod: "write32",
        size: 4,
        maxValue: 2 ** 32 - 1,
        ...options,
        name: options?.name ?? "u32"
      });
    },
    u64(options) {
      return bigUIntBcsType({
        readMethod: "read64",
        writeMethod: "write64",
        size: 8,
        maxValue: 2n ** 64n - 1n,
        ...options,
        name: options?.name ?? "u64"
      });
    },
    u128(options) {
      return bigUIntBcsType({
        readMethod: "read128",
        writeMethod: "write128",
        size: 16,
        maxValue: 2n ** 128n - 1n,
        ...options,
        name: options?.name ?? "u128"
      });
    },
    u256(options) {
      return bigUIntBcsType({
        readMethod: "read256",
        writeMethod: "write256",
        size: 32,
        maxValue: 2n ** 256n - 1n,
        ...options,
        name: options?.name ?? "u256"
      });
    },
    bool(options) {
      return fixedSizeBcsType({
        size: 1,
        read: (reader) => reader.read8() === 1,
        write: (value, writer) => writer.write8(value ? 1 : 0),
        ...options,
        name: options?.name ?? "bool",
        validate: (value) => {
          options?.validate?.(value);
          if (typeof value !== "boolean") throw new TypeError(`Expected boolean, found ${typeof value}`);
        }
      });
    },
    uleb128(options) {
      return dynamicSizeBcsType({
        read: (reader) => reader.readULEB(),
        serialize: (value) => {
          return Uint8Array.from(ulebEncode(value));
        },
        ...options,
        name: options?.name ?? "uleb128"
      });
    },
    bytes(size, options) {
      return fixedSizeBcsType({
        size,
        read: (reader) => reader.readBytes(size),
        write: (value, writer) => {
          writer.writeBytes(new Uint8Array(value));
        },
        ...options,
        name: options?.name ?? `bytes[${size}]`,
        validate: (value) => {
          options?.validate?.(value);
          if (!value || typeof value !== "object" || !("length" in value)) throw new TypeError(`Expected array, found ${typeof value}`);
          if (value.length !== size) throw new TypeError(`Expected array of length ${size}, found ${value.length}`);
        }
      });
    },
    byteVector(options) {
      return new BcsType({
        read: (reader) => {
          const length = reader.readULEB();
          return reader.readBytes(length);
        },
        write: (value, writer) => {
          const array = new Uint8Array(value);
          writer.writeULEB(array.length);
          writer.writeBytes(array);
        },
        ...options,
        name: options?.name ?? "vector<u8>",
        serializedSize: (value) => {
          const length = "length" in value ? value.length : null;
          return length == null ? null : ulebEncode(length).length + length;
        },
        validate: (value) => {
          options?.validate?.(value);
          if (!value || typeof value !== "object" || !("length" in value)) throw new TypeError(`Expected array, found ${typeof value}`);
        }
      });
    },
    string(options) {
      return stringLikeBcsType({
        toBytes: (value) => new TextEncoder().encode(value),
        fromBytes: (bytes) => new TextDecoder().decode(bytes),
        ...options,
        name: options?.name ?? "string"
      });
    },
    fixedArray,
    option,
    vector,
    tuple(fields, options) {
      return new BcsTuple({
        fields,
        ...options
      });
    },
    struct(name, fields, options) {
      return new BcsStruct({
        name,
        fields,
        ...options
      });
    },
    enum(name, fields, options) {
      return new BcsEnum({
        name,
        fields,
        ...options
      });
    },
    map,
    lazy(cb) {
      return lazyBcsType(cb);
    }
  };

  // node_modules/@mysten/sui/dist/utils/sui-types.mjs
  var SUI_ADDRESS_LENGTH = 32;
  function isValidSuiAddress(value) {
    return isHex(value) && getHexByteLength(value) === SUI_ADDRESS_LENGTH;
  }
  function normalizeSuiAddress(value, forceAdd0x = false) {
    let address = value.toLowerCase();
    if (!forceAdd0x && address.startsWith("0x")) address = address.slice(2);
    return `0x${address.padStart(SUI_ADDRESS_LENGTH * 2, "0")}`;
  }
  function isHex(value) {
    return /^(0x|0X)?[a-fA-F0-9]+$/.test(value) && value.length % 2 === 0;
  }
  function getHexByteLength(value) {
    return /^(0x|0X)/.test(value) ? (value.length - 2) / 2 : value.length / 2;
  }

  // node_modules/@mysten/sui/dist/bcs/type-tag-serializer.mjs
  var VECTOR_REGEX = /^vector<(.+)>$/;
  var STRUCT_REGEX = /^([^:]+)::([^:]+)::([^<]+)(<(.+)>)?/;
  var TypeTagSerializer = class TypeTagSerializer2 {
    static parseFromStr(str, normalizeAddress = false) {
      if (str === "address") return { address: null };
      else if (str === "bool") return { bool: null };
      else if (str === "u8") return { u8: null };
      else if (str === "u16") return { u16: null };
      else if (str === "u32") return { u32: null };
      else if (str === "u64") return { u64: null };
      else if (str === "u128") return { u128: null };
      else if (str === "u256") return { u256: null };
      else if (str === "signer") return { signer: null };
      const vectorMatch = str.match(VECTOR_REGEX);
      if (vectorMatch) return { vector: TypeTagSerializer2.parseFromStr(vectorMatch[1], normalizeAddress) };
      const structMatch = str.match(STRUCT_REGEX);
      if (structMatch) return { struct: {
        address: normalizeAddress ? normalizeSuiAddress(structMatch[1]) : structMatch[1],
        module: structMatch[2],
        name: structMatch[3],
        typeParams: structMatch[5] === void 0 ? [] : TypeTagSerializer2.parseStructTypeArgs(structMatch[5], normalizeAddress)
      } };
      throw new Error(`Encountered unexpected token when parsing type args for ${str}`);
    }
    static parseStructTypeArgs(str, normalizeAddress = false) {
      return splitGenericParameters(str).map((tok) => TypeTagSerializer2.parseFromStr(tok, normalizeAddress));
    }
    static tagToString(tag) {
      if ("bool" in tag) return "bool";
      if ("u8" in tag) return "u8";
      if ("u16" in tag) return "u16";
      if ("u32" in tag) return "u32";
      if ("u64" in tag) return "u64";
      if ("u128" in tag) return "u128";
      if ("u256" in tag) return "u256";
      if ("address" in tag) return "address";
      if ("signer" in tag) return "signer";
      if ("vector" in tag) return `vector<${TypeTagSerializer2.tagToString(tag.vector)}>`;
      if ("struct" in tag) {
        const struct = tag.struct;
        const typeParams = struct.typeParams.map(TypeTagSerializer2.tagToString).join(", ");
        return `${struct.address}::${struct.module}::${struct.name}${typeParams ? `<${typeParams}>` : ""}`;
      }
      throw new Error("Invalid TypeTag");
    }
  };

  // node_modules/@mysten/sui/dist/bcs/bcs.mjs
  function unsafe_u64(options) {
    return bcs.u64({
      name: "unsafe_u64",
      ...options
    }).transform({
      input: (val) => val,
      output: (val) => Number(val)
    });
  }
  function optionEnum(type) {
    return bcs.enum("Option", {
      None: null,
      Some: type
    });
  }
  var Address = bcs.bytes(SUI_ADDRESS_LENGTH).transform({
    validate: (val) => {
      const address = typeof val === "string" ? val : toHex(val);
      if (!address || !isValidSuiAddress(normalizeSuiAddress(address))) throw new Error(`Invalid Sui address ${address}`);
    },
    input: (val) => typeof val === "string" ? fromHex(normalizeSuiAddress(val)) : val,
    output: (val) => normalizeSuiAddress(toHex(val))
  });
  var ObjectDigest = bcs.byteVector().transform({
    name: "ObjectDigest",
    input: (value) => fromBase58(value),
    output: (value) => toBase58(new Uint8Array(value)),
    validate: (value) => {
      if (fromBase58(value).length !== 32) throw new Error("ObjectDigest must be 32 bytes");
    }
  });
  var SuiObjectRef = bcs.struct("SuiObjectRef", {
    objectId: Address,
    version: bcs.u64(),
    digest: ObjectDigest
  });
  var SharedObjectRef = bcs.struct("SharedObjectRef", {
    objectId: Address,
    initialSharedVersion: bcs.u64(),
    mutable: bcs.bool()
  });
  var ObjectArg = bcs.enum("ObjectArg", {
    ImmOrOwnedObject: SuiObjectRef,
    SharedObject: SharedObjectRef,
    Receiving: SuiObjectRef
  });
  var Owner = bcs.enum("Owner", {
    AddressOwner: Address,
    ObjectOwner: Address,
    Shared: bcs.struct("Shared", { initialSharedVersion: bcs.u64() }),
    Immutable: null,
    ConsensusAddressOwner: bcs.struct("ConsensusAddressOwner", {
      startVersion: bcs.u64(),
      owner: Address
    })
  });
  var Reservation = bcs.enum("Reservation", { MaxAmountU64: bcs.u64() });
  var WithdrawalType = bcs.enum("WithdrawalType", { Balance: bcs.lazy(() => TypeTag) });
  var WithdrawFrom = bcs.enum("WithdrawFrom", {
    Sender: null,
    Sponsor: null
  });
  var FundsWithdrawal = bcs.struct("FundsWithdrawal", {
    reservation: Reservation,
    typeArg: WithdrawalType,
    withdrawFrom: WithdrawFrom
  });
  var CallArg = bcs.enum("CallArg", {
    Pure: bcs.struct("Pure", { bytes: bcs.byteVector().transform({
      input: (val) => typeof val === "string" ? fromBase64(val) : val,
      output: (val) => toBase64(new Uint8Array(val))
    }) }),
    Object: ObjectArg,
    FundsWithdrawal
  });
  var InnerTypeTag = bcs.enum("TypeTag", {
    bool: null,
    u8: null,
    u64: null,
    u128: null,
    address: null,
    signer: null,
    vector: bcs.lazy(() => InnerTypeTag),
    struct: bcs.lazy(() => StructTag),
    u16: null,
    u32: null,
    u256: null
  });
  var TypeTag = InnerTypeTag.transform({
    input: (typeTag) => typeof typeTag === "string" ? TypeTagSerializer.parseFromStr(typeTag, true) : typeTag,
    output: (typeTag) => TypeTagSerializer.tagToString(typeTag)
  });
  var Argument = bcs.enum("Argument", {
    GasCoin: null,
    Input: bcs.u16(),
    Result: bcs.u16(),
    NestedResult: bcs.tuple([bcs.u16(), bcs.u16()])
  });
  var ProgrammableMoveCall = bcs.struct("ProgrammableMoveCall", {
    package: Address,
    module: bcs.string(),
    function: bcs.string(),
    typeArguments: bcs.vector(TypeTag),
    arguments: bcs.vector(Argument)
  });
  var Command = bcs.enum("Command", {
    MoveCall: ProgrammableMoveCall,
    TransferObjects: bcs.struct("TransferObjects", {
      objects: bcs.vector(Argument),
      address: Argument
    }),
    SplitCoins: bcs.struct("SplitCoins", {
      coin: Argument,
      amounts: bcs.vector(Argument)
    }),
    MergeCoins: bcs.struct("MergeCoins", {
      destination: Argument,
      sources: bcs.vector(Argument)
    }),
    Publish: bcs.struct("Publish", {
      modules: bcs.vector(bcs.byteVector().transform({
        input: (val) => typeof val === "string" ? fromBase64(val) : val,
        output: (val) => toBase64(new Uint8Array(val))
      })),
      dependencies: bcs.vector(Address)
    }),
    MakeMoveVec: bcs.struct("MakeMoveVec", {
      type: optionEnum(TypeTag).transform({
        input: (val) => val === null ? { None: true } : { Some: val },
        output: (val) => val.Some ?? null
      }),
      elements: bcs.vector(Argument)
    }),
    Upgrade: bcs.struct("Upgrade", {
      modules: bcs.vector(bcs.byteVector().transform({
        input: (val) => typeof val === "string" ? fromBase64(val) : val,
        output: (val) => toBase64(new Uint8Array(val))
      })),
      dependencies: bcs.vector(Address),
      package: Address,
      ticket: Argument
    })
  });
  var ProgrammableTransaction = bcs.struct("ProgrammableTransaction", {
    inputs: bcs.vector(CallArg),
    commands: bcs.vector(Command)
  });
  var TransactionKind = bcs.enum("TransactionKind", {
    ProgrammableTransaction,
    ChangeEpoch: null,
    Genesis: null,
    ConsensusCommitPrologue: null
  });
  var ValidDuring = bcs.struct("ValidDuring", {
    minEpoch: bcs.option(bcs.u64()),
    maxEpoch: bcs.option(bcs.u64()),
    minTimestamp: bcs.option(bcs.u64()),
    maxTimestamp: bcs.option(bcs.u64()),
    chain: ObjectDigest,
    nonce: bcs.u32()
  });
  var TransactionExpiration = bcs.enum("TransactionExpiration", {
    None: null,
    Epoch: unsafe_u64(),
    ValidDuring
  });
  var StructTag = bcs.struct("StructTag", {
    address: Address,
    module: bcs.string(),
    name: bcs.string(),
    typeParams: bcs.vector(InnerTypeTag)
  });
  var GasData = bcs.struct("GasData", {
    payment: bcs.vector(SuiObjectRef),
    owner: Address,
    price: bcs.u64(),
    budget: bcs.u64()
  });
  var TransactionDataV1 = bcs.struct("TransactionDataV1", {
    kind: TransactionKind,
    sender: Address,
    gasData: GasData,
    expiration: TransactionExpiration
  });
  var TransactionData = bcs.enum("TransactionData", { V1: TransactionDataV1 });
  var IntentScope = bcs.enum("IntentScope", {
    TransactionData: null,
    TransactionEffects: null,
    CheckpointSummary: null,
    PersonalMessage: null
  });
  var IntentVersion = bcs.enum("IntentVersion", { V0: null });
  var AppId = bcs.enum("AppId", { Sui: null });
  var Intent = bcs.struct("Intent", {
    scope: IntentScope,
    version: IntentVersion,
    appId: AppId
  });
  function IntentMessage(T) {
    return bcs.struct(`IntentMessage<${T.name}>`, {
      intent: Intent,
      value: T
    });
  }
  var CompressedSignature = bcs.enum("CompressedSignature", {
    ED25519: bcs.bytes(64),
    Secp256k1: bcs.bytes(64),
    Secp256r1: bcs.bytes(64),
    ZkLogin: bcs.byteVector(),
    Passkey: bcs.byteVector()
  });
  var PublicKey = bcs.enum("PublicKey", {
    ED25519: bcs.bytes(32),
    Secp256k1: bcs.bytes(33),
    Secp256r1: bcs.bytes(33),
    ZkLogin: bcs.byteVector(),
    Passkey: bcs.bytes(33)
  });
  var MultiSigPkMap = bcs.struct("MultiSigPkMap", {
    pubKey: PublicKey,
    weight: bcs.u8()
  });
  var MultiSigPublicKey = bcs.struct("MultiSigPublicKey", {
    pk_map: bcs.vector(MultiSigPkMap),
    threshold: bcs.u16()
  });
  var MultiSig = bcs.struct("MultiSig", {
    sigs: bcs.vector(CompressedSignature),
    bitmap: bcs.u16(),
    multisig_pk: MultiSigPublicKey
  });
  var base64String = bcs.byteVector().transform({
    input: (val) => typeof val === "string" ? fromBase64(val) : val,
    output: (val) => toBase64(new Uint8Array(val))
  });
  var SenderSignedTransaction = bcs.struct("SenderSignedTransaction", {
    intentMessage: IntentMessage(TransactionData),
    txSignatures: bcs.vector(base64String)
  });
  var SenderSignedData = bcs.vector(SenderSignedTransaction, { name: "SenderSignedData" });
  var PasskeyAuthenticator = bcs.struct("PasskeyAuthenticator", {
    authenticatorData: bcs.byteVector(),
    clientDataJson: bcs.string(),
    userSignature: bcs.byteVector()
  });
  var MoveObjectType = bcs.enum("MoveObjectType", {
    Other: StructTag,
    GasCoin: null,
    StakedSui: null,
    Coin: TypeTag,
    AccumulatorBalanceWrapper: null
  });
  var TypeOrigin = bcs.struct("TypeOrigin", {
    moduleName: bcs.string(),
    datatypeName: bcs.string(),
    package: Address
  });
  var UpgradeInfo = bcs.struct("UpgradeInfo", {
    upgradedId: Address,
    upgradedVersion: bcs.u64()
  });
  var MovePackage = bcs.struct("MovePackage", {
    id: Address,
    version: bcs.u64(),
    moduleMap: bcs.map(bcs.string(), bcs.byteVector()),
    typeOriginTable: bcs.vector(TypeOrigin),
    linkageTable: bcs.map(Address, UpgradeInfo)
  });
  var MoveObject = bcs.struct("MoveObject", {
    type: MoveObjectType,
    hasPublicTransfer: bcs.bool(),
    version: bcs.u64(),
    contents: bcs.byteVector()
  });
  var Data = bcs.enum("Data", {
    Move: MoveObject,
    Package: MovePackage
  });
  var ObjectInner = bcs.struct("ObjectInner", {
    data: Data,
    owner: Owner,
    previousTransaction: ObjectDigest,
    storageRebate: bcs.u64()
  });

  // node_modules/@mysten/sui/dist/bcs/effects.mjs
  var PackageUpgradeError = bcs.enum("PackageUpgradeError", {
    UnableToFetchPackage: bcs.struct("UnableToFetchPackage", { packageId: Address }),
    NotAPackage: bcs.struct("NotAPackage", { objectId: Address }),
    IncompatibleUpgrade: null,
    DigestDoesNotMatch: bcs.struct("DigestDoesNotMatch", { digest: bcs.byteVector() }),
    UnknownUpgradePolicy: bcs.struct("UnknownUpgradePolicy", { policy: bcs.u8() }),
    PackageIDDoesNotMatch: bcs.struct("PackageIDDoesNotMatch", {
      packageId: Address,
      ticketId: Address
    })
  });
  var ModuleId = bcs.struct("ModuleId", {
    address: Address,
    name: bcs.string()
  });
  var MoveLocation = bcs.struct("MoveLocation", {
    module: ModuleId,
    function: bcs.u16(),
    instruction: bcs.u16(),
    functionName: bcs.option(bcs.string())
  });
  var CommandArgumentError = bcs.enum("CommandArgumentError", {
    TypeMismatch: null,
    InvalidBCSBytes: null,
    InvalidUsageOfPureArg: null,
    InvalidArgumentToPrivateEntryFunction: null,
    IndexOutOfBounds: bcs.struct("IndexOutOfBounds", { idx: bcs.u16() }),
    SecondaryIndexOutOfBounds: bcs.struct("SecondaryIndexOutOfBounds", {
      resultIdx: bcs.u16(),
      secondaryIdx: bcs.u16()
    }),
    InvalidResultArity: bcs.struct("InvalidResultArity", { resultIdx: bcs.u16() }),
    InvalidGasCoinUsage: null,
    InvalidValueUsage: null,
    InvalidObjectByValue: null,
    InvalidObjectByMutRef: null,
    SharedObjectOperationNotAllowed: null,
    InvalidArgumentArity: null,
    InvalidTransferObject: null,
    InvalidMakeMoveVecNonObjectArgument: null,
    ArgumentWithoutValue: null,
    CannotMoveBorrowedValue: null,
    CannotWriteToExtendedReference: null,
    InvalidReferenceArgument: null
  });
  var TypeArgumentError = bcs.enum("TypeArgumentError", {
    TypeNotFound: null,
    ConstraintNotSatisfied: null
  });
  var ExecutionFailureStatus = bcs.enum("ExecutionFailureStatus", {
    InsufficientGas: null,
    InvalidGasObject: null,
    InvariantViolation: null,
    FeatureNotYetSupported: null,
    MoveObjectTooBig: bcs.struct("MoveObjectTooBig", {
      objectSize: bcs.u64(),
      maxObjectSize: bcs.u64()
    }),
    MovePackageTooBig: bcs.struct("MovePackageTooBig", {
      objectSize: bcs.u64(),
      maxObjectSize: bcs.u64()
    }),
    CircularObjectOwnership: bcs.struct("CircularObjectOwnership", { object: Address }),
    InsufficientCoinBalance: null,
    CoinBalanceOverflow: null,
    PublishErrorNonZeroAddress: null,
    SuiMoveVerificationError: null,
    MovePrimitiveRuntimeError: bcs.option(MoveLocation),
    MoveAbort: bcs.tuple([MoveLocation, bcs.u64()]),
    VMVerificationOrDeserializationError: null,
    VMInvariantViolation: null,
    FunctionNotFound: null,
    ArityMismatch: null,
    TypeArityMismatch: null,
    NonEntryFunctionInvoked: null,
    CommandArgumentError: bcs.struct("CommandArgumentError", {
      argIdx: bcs.u16(),
      kind: CommandArgumentError
    }),
    TypeArgumentError: bcs.struct("TypeArgumentError", {
      argumentIdx: bcs.u16(),
      kind: TypeArgumentError
    }),
    UnusedValueWithoutDrop: bcs.struct("UnusedValueWithoutDrop", {
      resultIdx: bcs.u16(),
      secondaryIdx: bcs.u16()
    }),
    InvalidPublicFunctionReturnType: bcs.struct("InvalidPublicFunctionReturnType", { idx: bcs.u16() }),
    InvalidTransferObject: null,
    EffectsTooLarge: bcs.struct("EffectsTooLarge", {
      currentSize: bcs.u64(),
      maxSize: bcs.u64()
    }),
    PublishUpgradeMissingDependency: null,
    PublishUpgradeDependencyDowngrade: null,
    PackageUpgradeError: bcs.struct("PackageUpgradeError", { upgradeError: PackageUpgradeError }),
    WrittenObjectsTooLarge: bcs.struct("WrittenObjectsTooLarge", {
      currentSize: bcs.u64(),
      maxSize: bcs.u64()
    }),
    CertificateDenied: null,
    SuiMoveVerificationTimedout: null,
    SharedObjectOperationNotAllowed: null,
    InputObjectDeleted: null,
    ExecutionCancelledDueToSharedObjectCongestion: bcs.struct("ExecutionCancelledDueToSharedObjectCongestion", { congested_objects: bcs.vector(Address) }),
    AddressDeniedForCoin: bcs.struct("AddressDeniedForCoin", {
      address: Address,
      coinType: bcs.string()
    }),
    CoinTypeGlobalPause: bcs.struct("CoinTypeGlobalPause", { coinType: bcs.string() }),
    ExecutionCancelledDueToRandomnessUnavailable: null,
    MoveVectorElemTooBig: bcs.struct("MoveVectorElemTooBig", {
      valueSize: bcs.u64(),
      maxScaledSize: bcs.u64()
    }),
    MoveRawValueTooBig: bcs.struct("MoveRawValueTooBig", {
      valueSize: bcs.u64(),
      maxScaledSize: bcs.u64()
    }),
    InvalidLinkage: null,
    InsufficientBalanceForWithdraw: null,
    NonExclusiveWriteInputObjectModified: bcs.struct("NonExclusiveWriteInputObjectModified", { id: Address })
  });
  var ExecutionStatus = bcs.enum("ExecutionStatus", {
    Success: null,
    Failure: bcs.struct("Failure", {
      error: ExecutionFailureStatus,
      command: bcs.option(bcs.u64())
    })
  });
  var GasCostSummary = bcs.struct("GasCostSummary", {
    computationCost: bcs.u64(),
    storageCost: bcs.u64(),
    storageRebate: bcs.u64(),
    nonRefundableStorageFee: bcs.u64()
  });
  var TransactionEffectsV1 = bcs.struct("TransactionEffectsV1", {
    status: ExecutionStatus,
    executedEpoch: bcs.u64(),
    gasUsed: GasCostSummary,
    modifiedAtVersions: bcs.vector(bcs.tuple([Address, bcs.u64()])),
    sharedObjects: bcs.vector(SuiObjectRef),
    transactionDigest: ObjectDigest,
    created: bcs.vector(bcs.tuple([SuiObjectRef, Owner])),
    mutated: bcs.vector(bcs.tuple([SuiObjectRef, Owner])),
    unwrapped: bcs.vector(bcs.tuple([SuiObjectRef, Owner])),
    deleted: bcs.vector(SuiObjectRef),
    unwrappedThenDeleted: bcs.vector(SuiObjectRef),
    wrapped: bcs.vector(SuiObjectRef),
    gasObject: bcs.tuple([SuiObjectRef, Owner]),
    eventsDigest: bcs.option(ObjectDigest),
    dependencies: bcs.vector(ObjectDigest)
  });
  var VersionDigest = bcs.tuple([bcs.u64(), ObjectDigest]);
  var ObjectIn = bcs.enum("ObjectIn", {
    NotExist: null,
    Exist: bcs.tuple([VersionDigest, Owner])
  });
  var AccumulatorAddress = bcs.struct("AccumulatorAddress", {
    address: Address,
    ty: TypeTag
  });
  var AccumulatorOperation = bcs.enum("AccumulatorOperation", {
    Merge: null,
    Split: null
  });
  var AccumulatorValue = bcs.enum("AccumulatorValue", {
    Integer: bcs.u64(),
    IntegerTuple: bcs.tuple([bcs.u64(), bcs.u64()]),
    EventDigest: bcs.vector(bcs.tuple([bcs.u64(), ObjectDigest]))
  });
  var AccumulatorWriteV1 = bcs.struct("AccumulatorWriteV1", {
    address: AccumulatorAddress,
    operation: AccumulatorOperation,
    value: AccumulatorValue
  });
  var ObjectOut = bcs.enum("ObjectOut", {
    NotExist: null,
    ObjectWrite: bcs.tuple([ObjectDigest, Owner]),
    PackageWrite: VersionDigest,
    AccumulatorWriteV1
  });
  var IDOperation = bcs.enum("IDOperation", {
    None: null,
    Created: null,
    Deleted: null
  });
  var EffectsObjectChange = bcs.struct("EffectsObjectChange", {
    inputState: ObjectIn,
    outputState: ObjectOut,
    idOperation: IDOperation
  });
  var UnchangedConsensusKind = bcs.enum("UnchangedConsensusKind", {
    ReadOnlyRoot: VersionDigest,
    MutateConsensusStreamEnded: bcs.u64(),
    ReadConsensusStreamEnded: bcs.u64(),
    Cancelled: bcs.u64(),
    PerEpochConfig: null
  });
  var TransactionEffectsV2 = bcs.struct("TransactionEffectsV2", {
    status: ExecutionStatus,
    executedEpoch: bcs.u64(),
    gasUsed: GasCostSummary,
    transactionDigest: ObjectDigest,
    gasObjectIndex: bcs.option(bcs.u32()),
    eventsDigest: bcs.option(ObjectDigest),
    dependencies: bcs.vector(ObjectDigest),
    lamportVersion: bcs.u64(),
    changedObjects: bcs.vector(bcs.tuple([Address, EffectsObjectChange])),
    unchangedConsensusObjects: bcs.vector(bcs.tuple([Address, UnchangedConsensusKind])),
    auxDataDigest: bcs.option(ObjectDigest)
  });
  var TransactionEffects = bcs.enum("TransactionEffects", {
    V1: TransactionEffectsV1,
    V2: TransactionEffectsV2
  });

  // node_modules/@mysten/sui/dist/bcs/index.mjs
  var suiBcs = {
    ...bcs,
    U8: bcs.u8(),
    U16: bcs.u16(),
    U32: bcs.u32(),
    U64: bcs.u64(),
    U128: bcs.u128(),
    U256: bcs.u256(),
    ULEB128: bcs.uleb128(),
    Bool: bcs.bool(),
    String: bcs.string(),
    Address,
    AppId,
    Argument,
    CallArg,
    Command,
    CompressedSignature,
    Data,
    GasData,
    Intent,
    IntentMessage,
    IntentScope,
    IntentVersion,
    MoveObject,
    MoveObjectType,
    MovePackage,
    MultiSig,
    MultiSigPkMap,
    MultiSigPublicKey,
    Object: ObjectInner,
    ObjectArg,
    ObjectDigest,
    Owner,
    PasskeyAuthenticator,
    ProgrammableMoveCall,
    ProgrammableTransaction,
    PublicKey,
    SenderSignedData,
    SenderSignedTransaction,
    SharedObjectRef,
    StructTag,
    SuiObjectRef,
    TransactionData,
    TransactionDataV1,
    TransactionEffects,
    TransactionExpiration,
    TransactionKind,
    TypeOrigin,
    TypeTag,
    UpgradeInfo
  };

  // node_modules/@mysten/sui/dist/cryptography/intent.mjs
  function messageWithIntent(scope, message) {
    return suiBcs.IntentMessage(suiBcs.bytes(message.length)).serialize({
      intent: {
        scope: { [scope]: true },
        version: { V0: true },
        appId: { Sui: true }
      },
      value: message
    }).toBytes();
  }

  // node_modules/@mysten/sui/dist/cryptography/signature-scheme.mjs
  var SIGNATURE_SCHEME_TO_FLAG = {
    ED25519: 0,
    Secp256k1: 1,
    Secp256r1: 2,
    MultiSig: 3,
    ZkLogin: 5,
    Passkey: 6
  };
  var SIGNATURE_SCHEME_TO_SIZE = {
    ED25519: 32,
    Secp256k1: 33,
    Secp256r1: 33,
    Passkey: 33
  };
  var SIGNATURE_FLAG_TO_SCHEME = {
    0: "ED25519",
    1: "Secp256k1",
    2: "Secp256r1",
    3: "MultiSig",
    5: "ZkLogin",
    6: "Passkey"
  };

  // node_modules/@noble/hashes/utils.js
  function isBytes2(a) {
    return a instanceof Uint8Array || ArrayBuffer.isView(a) && a.constructor.name === "Uint8Array" && "BYTES_PER_ELEMENT" in a && a.BYTES_PER_ELEMENT === 1;
  }
  function anumber2(n, title = "") {
    if (typeof n !== "number") {
      const prefix = title && `"${title}" `;
      throw new TypeError(`${prefix}expected number, got ${typeof n}`);
    }
    if (!Number.isSafeInteger(n) || n < 0) {
      const prefix = title && `"${title}" `;
      throw new RangeError(`${prefix}expected integer >= 0, got ${n}`);
    }
  }
  function abytes(value, length, title = "") {
    const bytes = isBytes2(value);
    const len = value?.length;
    const needsLen = length !== void 0;
    if (!bytes || needsLen && len !== length) {
      const prefix = title && `"${title}" `;
      const ofLen = needsLen ? ` of length ${length}` : "";
      const got = bytes ? `length=${len}` : `type=${typeof value}`;
      const message = prefix + "expected Uint8Array" + ofLen + ", got " + got;
      if (!bytes)
        throw new TypeError(message);
      throw new RangeError(message);
    }
    return value;
  }
  function ahash(h) {
    if (typeof h !== "function" || typeof h.create !== "function")
      throw new TypeError("Hash must wrapped by utils.createHasher");
    anumber2(h.outputLen);
    anumber2(h.blockLen);
    if (h.outputLen < 1)
      throw new Error('"outputLen" must be >= 1');
    if (h.blockLen < 1)
      throw new Error('"blockLen" must be >= 1');
  }
  function aexists(instance, checkFinished = true) {
    if (instance.destroyed)
      throw new Error("Hash instance has been destroyed");
    if (checkFinished && instance.finished)
      throw new Error("Hash#digest() has already been called");
  }
  function aoutput(out, instance) {
    abytes(out, void 0, "digestInto() output");
    const min = instance.outputLen;
    if (out.length < min) {
      throw new RangeError('"digestInto() output" expected to be of length >=' + min);
    }
  }
  function u32(arr) {
    return new Uint32Array(arr.buffer, arr.byteOffset, Math.floor(arr.byteLength / 4));
  }
  function clean(...arrays) {
    for (let i = 0; i < arrays.length; i++) {
      arrays[i].fill(0);
    }
  }
  function createView(arr) {
    return new DataView(arr.buffer, arr.byteOffset, arr.byteLength);
  }
  function rotr(word, shift) {
    return word << 32 - shift | word >>> shift;
  }
  var isLE = /* @__PURE__ */ (() => new Uint8Array(new Uint32Array([287454020]).buffer)[0] === 68)();
  function byteSwap(word) {
    return word << 24 & 4278190080 | word << 8 & 16711680 | word >>> 8 & 65280 | word >>> 24 & 255;
  }
  var swap8IfBE = isLE ? (n) => n : (n) => byteSwap(n) >>> 0;
  function byteSwap32(arr) {
    for (let i = 0; i < arr.length; i++) {
      arr[i] = byteSwap(arr[i]);
    }
    return arr;
  }
  var swap32IfBE = isLE ? (u) => u : byteSwap32;
  var hasHexBuiltin = /* @__PURE__ */ (() => (
    // @ts-ignore
    typeof Uint8Array.from([]).toHex === "function" && typeof Uint8Array.fromHex === "function"
  ))();
  var hexes = /* @__PURE__ */ Array.from({ length: 256 }, (_, i) => i.toString(16).padStart(2, "0"));
  function bytesToHex(bytes) {
    abytes(bytes);
    if (hasHexBuiltin)
      return bytes.toHex();
    let hex = "";
    for (let i = 0; i < bytes.length; i++) {
      hex += hexes[bytes[i]];
    }
    return hex;
  }
  var asciis = { _0: 48, _9: 57, A: 65, F: 70, a: 97, f: 102 };
  function asciiToBase16(ch) {
    if (ch >= asciis._0 && ch <= asciis._9)
      return ch - asciis._0;
    if (ch >= asciis.A && ch <= asciis.F)
      return ch - (asciis.A - 10);
    if (ch >= asciis.a && ch <= asciis.f)
      return ch - (asciis.a - 10);
    return;
  }
  function hexToBytes(hex) {
    if (typeof hex !== "string")
      throw new TypeError("hex string expected, got " + typeof hex);
    if (hasHexBuiltin) {
      try {
        return Uint8Array.fromHex(hex);
      } catch (error) {
        if (error instanceof SyntaxError)
          throw new RangeError(error.message);
        throw error;
      }
    }
    const hl = hex.length;
    const al = hl / 2;
    if (hl % 2)
      throw new RangeError("hex string expected, got unpadded hex of length " + hl);
    const array = new Uint8Array(al);
    for (let ai = 0, hi = 0; ai < al; ai++, hi += 2) {
      const n1 = asciiToBase16(hex.charCodeAt(hi));
      const n2 = asciiToBase16(hex.charCodeAt(hi + 1));
      if (n1 === void 0 || n2 === void 0) {
        const char = hex[hi] + hex[hi + 1];
        throw new RangeError('hex string expected, got non-hex character "' + char + '" at index ' + hi);
      }
      array[ai] = n1 * 16 + n2;
    }
    return array;
  }
  function concatBytes(...arrays) {
    let sum = 0;
    for (let i = 0; i < arrays.length; i++) {
      const a = arrays[i];
      abytes(a);
      sum += a.length;
    }
    const res = new Uint8Array(sum);
    for (let i = 0, pad = 0; i < arrays.length; i++) {
      const a = arrays[i];
      res.set(a, pad);
      pad += a.length;
    }
    return res;
  }
  function createHasher(hashCons, info = {}) {
    const hashC = (msg, opts) => hashCons(opts).update(msg).digest();
    const tmp = hashCons(void 0);
    hashC.outputLen = tmp.outputLen;
    hashC.blockLen = tmp.blockLen;
    hashC.canXOF = tmp.canXOF;
    hashC.create = (opts) => hashCons(opts);
    Object.assign(hashC, info);
    return Object.freeze(hashC);
  }
  function randomBytes(bytesLength = 32) {
    anumber2(bytesLength, "bytesLength");
    const cr = typeof globalThis === "object" ? globalThis.crypto : null;
    if (typeof cr?.getRandomValues !== "function")
      throw new Error("crypto.getRandomValues must be defined");
    if (bytesLength > 65536)
      throw new RangeError(`"bytesLength" expected <= 65536, got ${bytesLength}`);
    return cr.getRandomValues(new Uint8Array(bytesLength));
  }
  var oidNist = (suffix) => ({
    // Current NIST hashAlgs suffixes used here fit in one DER subidentifier octet.
    // Larger suffix values would need base-128 OID encoding and a different length byte.
    oid: Uint8Array.from([6, 9, 96, 134, 72, 1, 101, 3, 4, 2, suffix])
  });

  // node_modules/@noble/hashes/_blake.js
  var BSIGMA = /* @__PURE__ */ Uint8Array.from([
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    14,
    10,
    4,
    8,
    9,
    15,
    13,
    6,
    1,
    12,
    0,
    2,
    11,
    7,
    5,
    3,
    11,
    8,
    12,
    0,
    5,
    2,
    15,
    13,
    10,
    14,
    3,
    6,
    7,
    1,
    9,
    4,
    7,
    9,
    3,
    1,
    13,
    12,
    11,
    14,
    2,
    6,
    5,
    10,
    4,
    0,
    15,
    8,
    9,
    0,
    5,
    7,
    2,
    4,
    10,
    15,
    14,
    1,
    11,
    12,
    6,
    8,
    3,
    13,
    2,
    12,
    6,
    10,
    0,
    11,
    8,
    3,
    4,
    13,
    7,
    5,
    15,
    14,
    1,
    9,
    12,
    5,
    1,
    15,
    14,
    13,
    4,
    10,
    0,
    7,
    6,
    3,
    9,
    2,
    8,
    11,
    13,
    11,
    7,
    14,
    12,
    1,
    3,
    9,
    5,
    0,
    15,
    4,
    8,
    6,
    2,
    10,
    6,
    15,
    14,
    9,
    11,
    3,
    0,
    8,
    12,
    2,
    13,
    7,
    1,
    4,
    10,
    5,
    10,
    2,
    8,
    4,
    7,
    6,
    1,
    5,
    15,
    11,
    9,
    14,
    3,
    12,
    13,
    0,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    14,
    10,
    4,
    8,
    9,
    15,
    13,
    6,
    1,
    12,
    0,
    2,
    11,
    7,
    5,
    3,
    // Blake1, unused in others
    11,
    8,
    12,
    0,
    5,
    2,
    15,
    13,
    10,
    14,
    3,
    6,
    7,
    1,
    9,
    4,
    7,
    9,
    3,
    1,
    13,
    12,
    11,
    14,
    2,
    6,
    5,
    10,
    4,
    0,
    15,
    8,
    9,
    0,
    5,
    7,
    2,
    4,
    10,
    15,
    14,
    1,
    11,
    12,
    6,
    8,
    3,
    13,
    2,
    12,
    6,
    10,
    0,
    11,
    8,
    3,
    4,
    13,
    7,
    5,
    15,
    14,
    1,
    9
  ]);

  // node_modules/@noble/hashes/_md.js
  function Chi(a, b, c) {
    return a & b ^ ~a & c;
  }
  function Maj(a, b, c) {
    return a & b ^ a & c ^ b & c;
  }
  var HashMD = class {
    constructor(blockLen, outputLen, padOffset, isLE2) {
      __publicField(this, "blockLen");
      __publicField(this, "outputLen");
      __publicField(this, "canXOF", false);
      __publicField(this, "padOffset");
      __publicField(this, "isLE");
      // For partial updates less than block size
      __publicField(this, "buffer");
      __publicField(this, "view");
      __publicField(this, "finished", false);
      __publicField(this, "length", 0);
      __publicField(this, "pos", 0);
      __publicField(this, "destroyed", false);
      this.blockLen = blockLen;
      this.outputLen = outputLen;
      this.padOffset = padOffset;
      this.isLE = isLE2;
      this.buffer = new Uint8Array(blockLen);
      this.view = createView(this.buffer);
    }
    update(data) {
      aexists(this);
      abytes(data);
      const { view, buffer, blockLen } = this;
      const len = data.length;
      for (let pos = 0; pos < len; ) {
        const take = Math.min(blockLen - this.pos, len - pos);
        if (take === blockLen) {
          const dataView = createView(data);
          for (; blockLen <= len - pos; pos += blockLen)
            this.process(dataView, pos);
          continue;
        }
        buffer.set(data.subarray(pos, pos + take), this.pos);
        this.pos += take;
        pos += take;
        if (this.pos === blockLen) {
          this.process(view, 0);
          this.pos = 0;
        }
      }
      this.length += data.length;
      this.roundClean();
      return this;
    }
    digestInto(out) {
      aexists(this);
      aoutput(out, this);
      this.finished = true;
      const { buffer, view, blockLen, isLE: isLE2 } = this;
      let { pos } = this;
      buffer[pos++] = 128;
      clean(this.buffer.subarray(pos));
      if (this.padOffset > blockLen - pos) {
        this.process(view, 0);
        pos = 0;
      }
      for (let i = pos; i < blockLen; i++)
        buffer[i] = 0;
      view.setBigUint64(blockLen - 8, BigInt(this.length * 8), isLE2);
      this.process(view, 0);
      const oview = createView(out);
      const len = this.outputLen;
      if (len % 4)
        throw new Error("_sha2: outputLen must be aligned to 32bit");
      const outLen = len / 4;
      const state = this.get();
      if (outLen > state.length)
        throw new Error("_sha2: outputLen bigger than state");
      for (let i = 0; i < outLen; i++)
        oview.setUint32(4 * i, state[i], isLE2);
    }
    digest() {
      const { buffer, outputLen } = this;
      this.digestInto(buffer);
      const res = buffer.slice(0, outputLen);
      this.destroy();
      return res;
    }
    _cloneInto(to) {
      to || (to = new this.constructor());
      to.set(...this.get());
      const { blockLen, buffer, length, finished, destroyed, pos } = this;
      to.destroyed = destroyed;
      to.finished = finished;
      to.length = length;
      to.pos = pos;
      if (length % blockLen)
        to.buffer.set(buffer);
      return to;
    }
    clone() {
      return this._cloneInto();
    }
  };
  var SHA256_IV = /* @__PURE__ */ Uint32Array.from([
    1779033703,
    3144134277,
    1013904242,
    2773480762,
    1359893119,
    2600822924,
    528734635,
    1541459225
  ]);

  // node_modules/@noble/hashes/_u64.js
  var U32_MASK64 = /* @__PURE__ */ BigInt(2 ** 32 - 1);
  var _32n = /* @__PURE__ */ BigInt(32);
  function fromBig(n, le = false) {
    if (le)
      return { h: Number(n & U32_MASK64), l: Number(n >> _32n & U32_MASK64) };
    return { h: Number(n >> _32n & U32_MASK64) | 0, l: Number(n & U32_MASK64) | 0 };
  }
  var rotrSH = (h, l, s) => h >>> s | l << 32 - s;
  var rotrSL = (h, l, s) => h << 32 - s | l >>> s;
  var rotrBH = (h, l, s) => h << 64 - s | l >>> s - 32;
  var rotrBL = (h, l, s) => h >>> s - 32 | l << 64 - s;
  var rotr32H = (_h, l) => l;
  var rotr32L = (h, _l) => h;
  function add(Ah, Al, Bh, Bl) {
    const l = (Al >>> 0) + (Bl >>> 0);
    return { h: Ah + Bh + (l / 2 ** 32 | 0) | 0, l: l | 0 };
  }
  var add3L = (Al, Bl, Cl) => (Al >>> 0) + (Bl >>> 0) + (Cl >>> 0);
  var add3H = (low, Ah, Bh, Ch) => Ah + Bh + Ch + (low / 2 ** 32 | 0) | 0;

  // node_modules/@noble/hashes/blake2.js
  var B2B_IV = /* @__PURE__ */ Uint32Array.from([
    4089235720,
    1779033703,
    2227873595,
    3144134277,
    4271175723,
    1013904242,
    1595750129,
    2773480762,
    2917565137,
    1359893119,
    725511199,
    2600822924,
    4215389547,
    528734635,
    327033209,
    1541459225
  ]);
  var BBUF = /* @__PURE__ */ new Uint32Array(32);
  function G1b(a, b, c, d, msg, x) {
    const Xl = msg[x], Xh = msg[x + 1];
    let Al = BBUF[2 * a], Ah = BBUF[2 * a + 1];
    let Bl = BBUF[2 * b], Bh = BBUF[2 * b + 1];
    let Cl = BBUF[2 * c], Ch = BBUF[2 * c + 1];
    let Dl = BBUF[2 * d], Dh = BBUF[2 * d + 1];
    let ll = add3L(Al, Bl, Xl);
    Ah = add3H(ll, Ah, Bh, Xh);
    Al = ll | 0;
    ({ Dh, Dl } = { Dh: Dh ^ Ah, Dl: Dl ^ Al });
    ({ Dh, Dl } = { Dh: rotr32H(Dh, Dl), Dl: rotr32L(Dh, Dl) });
    ({ h: Ch, l: Cl } = add(Ch, Cl, Dh, Dl));
    ({ Bh, Bl } = { Bh: Bh ^ Ch, Bl: Bl ^ Cl });
    ({ Bh, Bl } = { Bh: rotrSH(Bh, Bl, 24), Bl: rotrSL(Bh, Bl, 24) });
    BBUF[2 * a] = Al, BBUF[2 * a + 1] = Ah;
    BBUF[2 * b] = Bl, BBUF[2 * b + 1] = Bh;
    BBUF[2 * c] = Cl, BBUF[2 * c + 1] = Ch;
    BBUF[2 * d] = Dl, BBUF[2 * d + 1] = Dh;
  }
  function G2b(a, b, c, d, msg, x) {
    const Xl = msg[x], Xh = msg[x + 1];
    let Al = BBUF[2 * a], Ah = BBUF[2 * a + 1];
    let Bl = BBUF[2 * b], Bh = BBUF[2 * b + 1];
    let Cl = BBUF[2 * c], Ch = BBUF[2 * c + 1];
    let Dl = BBUF[2 * d], Dh = BBUF[2 * d + 1];
    let ll = add3L(Al, Bl, Xl);
    Ah = add3H(ll, Ah, Bh, Xh);
    Al = ll | 0;
    ({ Dh, Dl } = { Dh: Dh ^ Ah, Dl: Dl ^ Al });
    ({ Dh, Dl } = { Dh: rotrSH(Dh, Dl, 16), Dl: rotrSL(Dh, Dl, 16) });
    ({ h: Ch, l: Cl } = add(Ch, Cl, Dh, Dl));
    ({ Bh, Bl } = { Bh: Bh ^ Ch, Bl: Bl ^ Cl });
    ({ Bh, Bl } = { Bh: rotrBH(Bh, Bl, 63), Bl: rotrBL(Bh, Bl, 63) });
    BBUF[2 * a] = Al, BBUF[2 * a + 1] = Ah;
    BBUF[2 * b] = Bl, BBUF[2 * b + 1] = Bh;
    BBUF[2 * c] = Cl, BBUF[2 * c + 1] = Ch;
    BBUF[2 * d] = Dl, BBUF[2 * d + 1] = Dh;
  }
  function checkBlake2Opts(outputLen, opts = {}, keyLen, saltLen, persLen) {
    anumber2(keyLen);
    if (outputLen <= 0 || outputLen > keyLen)
      throw new Error("outputLen bigger than keyLen");
    const { key, salt, personalization } = opts;
    if (key !== void 0 && (key.length < 1 || key.length > keyLen))
      throw new Error('"key" expected to be undefined or of length=1..' + keyLen);
    if (salt !== void 0)
      abytes(salt, saltLen, "salt");
    if (personalization !== void 0)
      abytes(personalization, persLen, "personalization");
  }
  var _BLAKE2 = class {
    constructor(blockLen, outputLen) {
      __publicField(this, "buffer");
      __publicField(this, "buffer32");
      __publicField(this, "finished", false);
      __publicField(this, "destroyed", false);
      __publicField(this, "length", 0);
      __publicField(this, "pos", 0);
      __publicField(this, "blockLen");
      __publicField(this, "outputLen");
      __publicField(this, "canXOF", false);
      anumber2(blockLen);
      anumber2(outputLen);
      this.blockLen = blockLen;
      this.outputLen = outputLen;
      this.buffer = new Uint8Array(blockLen);
      this.buffer32 = u32(this.buffer);
    }
    update(data) {
      aexists(this);
      abytes(data);
      const { blockLen, buffer, buffer32 } = this;
      const len = data.length;
      const offset = data.byteOffset;
      const buf = data.buffer;
      for (let pos = 0; pos < len; ) {
        if (this.pos === blockLen) {
          swap32IfBE(buffer32);
          this.compress(buffer32, 0, false);
          swap32IfBE(buffer32);
          this.pos = 0;
        }
        const take = Math.min(blockLen - this.pos, len - pos);
        const dataOffset = offset + pos;
        if (take === blockLen && !(dataOffset % 4) && pos + take < len) {
          const data32 = new Uint32Array(buf, dataOffset, Math.floor((len - pos) / 4));
          swap32IfBE(data32);
          for (let pos32 = 0; pos + blockLen < len; pos32 += buffer32.length, pos += blockLen) {
            this.length += blockLen;
            this.compress(data32, pos32, false);
          }
          swap32IfBE(data32);
          continue;
        }
        buffer.set(data.subarray(pos, pos + take), this.pos);
        this.pos += take;
        this.length += take;
        pos += take;
      }
      return this;
    }
    digestInto(out) {
      aexists(this);
      aoutput(out, this);
      const { pos, buffer32 } = this;
      this.finished = true;
      clean(this.buffer.subarray(pos));
      swap32IfBE(buffer32);
      this.compress(buffer32, 0, true);
      swap32IfBE(buffer32);
      if (out.byteOffset & 3)
        throw new RangeError('"digestInto() output" expected 4-byte aligned byteOffset, got ' + out.byteOffset);
      const state = this.get();
      const out32 = u32(out);
      const full = Math.floor(this.outputLen / 4);
      for (let i = 0; i < full; i++)
        out32[i] = swap8IfBE(state[i]);
      const tail = this.outputLen % 4;
      if (!tail)
        return;
      const off = full * 4;
      const word = state[full];
      for (let i = 0; i < tail; i++)
        out[off + i] = word >>> 8 * i;
    }
    digest() {
      const { buffer, outputLen } = this;
      this.digestInto(buffer);
      const res = buffer.slice(0, outputLen);
      this.destroy();
      return res;
    }
    _cloneInto(to) {
      const { buffer, length, finished, destroyed, outputLen, pos } = this;
      to || (to = new this.constructor({ dkLen: outputLen }));
      to.set(...this.get());
      to.buffer.set(buffer);
      to.destroyed = destroyed;
      to.finished = finished;
      to.length = length;
      to.pos = pos;
      to.outputLen = outputLen;
      return to;
    }
    clone() {
      return this._cloneInto();
    }
  };
  var _BLAKE2b = class extends _BLAKE2 {
    constructor(opts = {}) {
      const olen = opts.dkLen === void 0 ? 64 : opts.dkLen;
      super(128, olen);
      // Same IV words as SHA-512 / BLAKE2b, encoded as LE u32 low/high halves.
      __publicField(this, "v0l", B2B_IV[0] | 0);
      __publicField(this, "v0h", B2B_IV[1] | 0);
      __publicField(this, "v1l", B2B_IV[2] | 0);
      __publicField(this, "v1h", B2B_IV[3] | 0);
      __publicField(this, "v2l", B2B_IV[4] | 0);
      __publicField(this, "v2h", B2B_IV[5] | 0);
      __publicField(this, "v3l", B2B_IV[6] | 0);
      __publicField(this, "v3h", B2B_IV[7] | 0);
      __publicField(this, "v4l", B2B_IV[8] | 0);
      __publicField(this, "v4h", B2B_IV[9] | 0);
      __publicField(this, "v5l", B2B_IV[10] | 0);
      __publicField(this, "v5h", B2B_IV[11] | 0);
      __publicField(this, "v6l", B2B_IV[12] | 0);
      __publicField(this, "v6h", B2B_IV[13] | 0);
      __publicField(this, "v7l", B2B_IV[14] | 0);
      __publicField(this, "v7h", B2B_IV[15] | 0);
      checkBlake2Opts(olen, opts, 64, 16, 16);
      let { key, personalization, salt } = opts;
      let keyLength = 0;
      if (key !== void 0) {
        abytes(key, void 0, "key");
        keyLength = key.length;
      }
      this.v0l ^= this.outputLen | keyLength << 8 | 1 << 16 | 1 << 24;
      if (salt !== void 0) {
        abytes(salt, void 0, "salt");
        const slt = u32(salt);
        this.v4l ^= swap8IfBE(slt[0]);
        this.v4h ^= swap8IfBE(slt[1]);
        this.v5l ^= swap8IfBE(slt[2]);
        this.v5h ^= swap8IfBE(slt[3]);
      }
      if (personalization !== void 0) {
        abytes(personalization, void 0, "personalization");
        const pers = u32(personalization);
        this.v6l ^= swap8IfBE(pers[0]);
        this.v6h ^= swap8IfBE(pers[1]);
        this.v7l ^= swap8IfBE(pers[2]);
        this.v7h ^= swap8IfBE(pers[3]);
      }
      if (key !== void 0) {
        const tmp = new Uint8Array(this.blockLen);
        tmp.set(key);
        this.update(tmp);
      }
    }
    // prettier-ignore
    get() {
      let { v0l, v0h, v1l, v1h, v2l, v2h, v3l, v3h, v4l, v4h, v5l, v5h, v6l, v6h, v7l, v7h } = this;
      return [v0l, v0h, v1l, v1h, v2l, v2h, v3l, v3h, v4l, v4h, v5l, v5h, v6l, v6h, v7l, v7h];
    }
    // prettier-ignore
    set(v0l, v0h, v1l, v1h, v2l, v2h, v3l, v3h, v4l, v4h, v5l, v5h, v6l, v6h, v7l, v7h) {
      this.v0l = v0l | 0;
      this.v0h = v0h | 0;
      this.v1l = v1l | 0;
      this.v1h = v1h | 0;
      this.v2l = v2l | 0;
      this.v2h = v2h | 0;
      this.v3l = v3l | 0;
      this.v3h = v3h | 0;
      this.v4l = v4l | 0;
      this.v4h = v4h | 0;
      this.v5l = v5l | 0;
      this.v5h = v5h | 0;
      this.v6l = v6l | 0;
      this.v6h = v6h | 0;
      this.v7l = v7l | 0;
      this.v7h = v7h | 0;
    }
    compress(msg, offset, isLast) {
      this.get().forEach((v, i) => BBUF[i] = v);
      BBUF.set(B2B_IV, 16);
      let { h, l } = fromBig(BigInt(this.length));
      BBUF[24] = B2B_IV[8] ^ l;
      BBUF[25] = B2B_IV[9] ^ h;
      if (isLast) {
        BBUF[28] = ~BBUF[28];
        BBUF[29] = ~BBUF[29];
      }
      let j = 0;
      const s = BSIGMA;
      for (let i = 0; i < 12; i++) {
        G1b(0, 4, 8, 12, msg, offset + 2 * s[j++]);
        G2b(0, 4, 8, 12, msg, offset + 2 * s[j++]);
        G1b(1, 5, 9, 13, msg, offset + 2 * s[j++]);
        G2b(1, 5, 9, 13, msg, offset + 2 * s[j++]);
        G1b(2, 6, 10, 14, msg, offset + 2 * s[j++]);
        G2b(2, 6, 10, 14, msg, offset + 2 * s[j++]);
        G1b(3, 7, 11, 15, msg, offset + 2 * s[j++]);
        G2b(3, 7, 11, 15, msg, offset + 2 * s[j++]);
        G1b(0, 5, 10, 15, msg, offset + 2 * s[j++]);
        G2b(0, 5, 10, 15, msg, offset + 2 * s[j++]);
        G1b(1, 6, 11, 12, msg, offset + 2 * s[j++]);
        G2b(1, 6, 11, 12, msg, offset + 2 * s[j++]);
        G1b(2, 7, 8, 13, msg, offset + 2 * s[j++]);
        G2b(2, 7, 8, 13, msg, offset + 2 * s[j++]);
        G1b(3, 4, 9, 14, msg, offset + 2 * s[j++]);
        G2b(3, 4, 9, 14, msg, offset + 2 * s[j++]);
      }
      this.v0l ^= BBUF[0] ^ BBUF[16];
      this.v0h ^= BBUF[1] ^ BBUF[17];
      this.v1l ^= BBUF[2] ^ BBUF[18];
      this.v1h ^= BBUF[3] ^ BBUF[19];
      this.v2l ^= BBUF[4] ^ BBUF[20];
      this.v2h ^= BBUF[5] ^ BBUF[21];
      this.v3l ^= BBUF[6] ^ BBUF[22];
      this.v3h ^= BBUF[7] ^ BBUF[23];
      this.v4l ^= BBUF[8] ^ BBUF[24];
      this.v4h ^= BBUF[9] ^ BBUF[25];
      this.v5l ^= BBUF[10] ^ BBUF[26];
      this.v5h ^= BBUF[11] ^ BBUF[27];
      this.v6l ^= BBUF[12] ^ BBUF[28];
      this.v6h ^= BBUF[13] ^ BBUF[29];
      this.v7l ^= BBUF[14] ^ BBUF[30];
      this.v7h ^= BBUF[15] ^ BBUF[31];
      clean(BBUF);
    }
    destroy() {
      this.destroyed = true;
      clean(this.buffer32);
      this.set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }
  };
  var blake2b = /* @__PURE__ */ createHasher((opts) => new _BLAKE2b(opts));

  // node_modules/@mysten/sui/dist/cryptography/publickey.mjs
  function bytesEqual(a, b) {
    if (a === b) return true;
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }
  var PublicKey2 = class {
    /**
    * Checks if two public keys are equal
    */
    equals(publicKey) {
      return bytesEqual(this.toRawBytes(), publicKey.toRawBytes());
    }
    /**
    * Return the base-64 representation of the public key
    */
    toBase64() {
      return toBase64(this.toRawBytes());
    }
    toString() {
      throw new Error("`toString` is not implemented on public keys. Use `toBase64()` or `toRawBytes()` instead.");
    }
    /**
    * Return the Sui representation of the public key encoded in
    * base-64. A Sui public key is formed by the concatenation
    * of the scheme flag with the raw bytes of the public key
    */
    toSuiPublicKey() {
      return toBase64(this.toSuiBytes());
    }
    verifyWithIntent(bytes, signature, intent) {
      const digest = blake2b(messageWithIntent(intent, bytes), { dkLen: 32 });
      return this.verify(digest, signature);
    }
    /**
    * Verifies that the signature is valid for for the provided PersonalMessage
    */
    verifyPersonalMessage(message, signature) {
      return this.verifyWithIntent(suiBcs.byteVector().serialize(message).toBytes(), signature, "PersonalMessage");
    }
    /**
    * Verifies that the signature is valid for for the provided Transaction
    */
    verifyTransaction(transaction, signature) {
      return this.verifyWithIntent(transaction, signature, "TransactionData");
    }
    /**
    * Verifies that the public key is associated with the provided address
    */
    verifyAddress(address) {
      return this.toSuiAddress() === address;
    }
    /**
    * Returns the bytes representation of the public key
    * prefixed with the signature scheme flag
    */
    toSuiBytes() {
      const rawBytes = this.toRawBytes();
      const suiBytes = new Uint8Array(rawBytes.length + 1);
      suiBytes.set([this.flag()]);
      suiBytes.set(rawBytes, 1);
      return suiBytes;
    }
    /**
    * Return the Sui address associated with this Ed25519 public key
    */
    toSuiAddress() {
      return normalizeSuiAddress(bytesToHex(blake2b(this.toSuiBytes(), { dkLen: 32 })).slice(0, SUI_ADDRESS_LENGTH * 2));
    }
  };
  function parseSerializedKeypairSignature(serializedSignature) {
    const bytes = fromBase64(serializedSignature);
    const signatureScheme = SIGNATURE_FLAG_TO_SCHEME[bytes[0]];
    switch (signatureScheme) {
      case "ED25519":
      case "Secp256k1":
      case "Secp256r1":
        const size = SIGNATURE_SCHEME_TO_SIZE[signatureScheme];
        const signature = bytes.slice(1, bytes.length - size);
        return {
          serializedSignature,
          signatureScheme,
          signature,
          publicKey: bytes.slice(1 + signature.length),
          bytes
        };
      default:
        throw new Error("Unsupported signature scheme");
    }
  }

  // node_modules/@noble/hashes/sha2.js
  var SHA256_K = /* @__PURE__ */ Uint32Array.from([
    1116352408,
    1899447441,
    3049323471,
    3921009573,
    961987163,
    1508970993,
    2453635748,
    2870763221,
    3624381080,
    310598401,
    607225278,
    1426881987,
    1925078388,
    2162078206,
    2614888103,
    3248222580,
    3835390401,
    4022224774,
    264347078,
    604807628,
    770255983,
    1249150122,
    1555081692,
    1996064986,
    2554220882,
    2821834349,
    2952996808,
    3210313671,
    3336571891,
    3584528711,
    113926993,
    338241895,
    666307205,
    773529912,
    1294757372,
    1396182291,
    1695183700,
    1986661051,
    2177026350,
    2456956037,
    2730485921,
    2820302411,
    3259730800,
    3345764771,
    3516065817,
    3600352804,
    4094571909,
    275423344,
    430227734,
    506948616,
    659060556,
    883997877,
    958139571,
    1322822218,
    1537002063,
    1747873779,
    1955562222,
    2024104815,
    2227730452,
    2361852424,
    2428436474,
    2756734187,
    3204031479,
    3329325298
  ]);
  var SHA256_W = /* @__PURE__ */ new Uint32Array(64);
  var SHA2_32B = class extends HashMD {
    constructor(outputLen) {
      super(64, outputLen, 8, false);
    }
    get() {
      const { A, B, C, D, E, F, G, H } = this;
      return [A, B, C, D, E, F, G, H];
    }
    // prettier-ignore
    set(A, B, C, D, E, F, G, H) {
      this.A = A | 0;
      this.B = B | 0;
      this.C = C | 0;
      this.D = D | 0;
      this.E = E | 0;
      this.F = F | 0;
      this.G = G | 0;
      this.H = H | 0;
    }
    process(view, offset) {
      for (let i = 0; i < 16; i++, offset += 4)
        SHA256_W[i] = view.getUint32(offset, false);
      for (let i = 16; i < 64; i++) {
        const W15 = SHA256_W[i - 15];
        const W2 = SHA256_W[i - 2];
        const s0 = rotr(W15, 7) ^ rotr(W15, 18) ^ W15 >>> 3;
        const s1 = rotr(W2, 17) ^ rotr(W2, 19) ^ W2 >>> 10;
        SHA256_W[i] = s1 + SHA256_W[i - 7] + s0 + SHA256_W[i - 16] | 0;
      }
      let { A, B, C, D, E, F, G, H } = this;
      for (let i = 0; i < 64; i++) {
        const sigma1 = rotr(E, 6) ^ rotr(E, 11) ^ rotr(E, 25);
        const T1 = H + sigma1 + Chi(E, F, G) + SHA256_K[i] + SHA256_W[i] | 0;
        const sigma0 = rotr(A, 2) ^ rotr(A, 13) ^ rotr(A, 22);
        const T2 = sigma0 + Maj(A, B, C) | 0;
        H = G;
        G = F;
        F = E;
        E = D + T1 | 0;
        D = C;
        C = B;
        B = A;
        A = T1 + T2 | 0;
      }
      A = A + this.A | 0;
      B = B + this.B | 0;
      C = C + this.C | 0;
      D = D + this.D | 0;
      E = E + this.E | 0;
      F = F + this.F | 0;
      G = G + this.G | 0;
      H = H + this.H | 0;
      this.set(A, B, C, D, E, F, G, H);
    }
    roundClean() {
      clean(SHA256_W);
    }
    destroy() {
      this.destroyed = true;
      this.set(0, 0, 0, 0, 0, 0, 0, 0);
      clean(this.buffer);
    }
  };
  var _SHA256 = class extends SHA2_32B {
    constructor() {
      super(32);
      // We cannot use array here since array allows indexing by variable
      // which means optimizer/compiler cannot use registers.
      __publicField(this, "A", SHA256_IV[0] | 0);
      __publicField(this, "B", SHA256_IV[1] | 0);
      __publicField(this, "C", SHA256_IV[2] | 0);
      __publicField(this, "D", SHA256_IV[3] | 0);
      __publicField(this, "E", SHA256_IV[4] | 0);
      __publicField(this, "F", SHA256_IV[5] | 0);
      __publicField(this, "G", SHA256_IV[6] | 0);
      __publicField(this, "H", SHA256_IV[7] | 0);
    }
  };
  var sha256 = /* @__PURE__ */ createHasher(
    () => new _SHA256(),
    /* @__PURE__ */ oidNist(1)
  );

  // node_modules/@noble/curves/utils.js
  var abytes2 = (value, length, title) => abytes(value, length, title);
  var anumber3 = anumber2;
  var bytesToHex2 = bytesToHex;
  var concatBytes2 = (...arrays) => concatBytes(...arrays);
  var hexToBytes2 = (hex) => hexToBytes(hex);
  var isBytes3 = isBytes2;
  var randomBytes2 = (bytesLength) => randomBytes(bytesLength);
  var _0n = /* @__PURE__ */ BigInt(0);
  var _1n = /* @__PURE__ */ BigInt(1);
  function abool(value, title = "") {
    if (typeof value !== "boolean") {
      const prefix = title && `"${title}" `;
      throw new TypeError(prefix + "expected boolean, got type=" + typeof value);
    }
    return value;
  }
  function abignumber(n) {
    if (typeof n === "bigint") {
      if (!isPosBig(n))
        throw new RangeError("positive bigint expected, got " + n);
    } else
      anumber3(n);
    return n;
  }
  function asafenumber(value, title = "") {
    if (typeof value !== "number") {
      const prefix = title && `"${title}" `;
      throw new TypeError(prefix + "expected number, got type=" + typeof value);
    }
    if (!Number.isSafeInteger(value)) {
      const prefix = title && `"${title}" `;
      throw new RangeError(prefix + "expected safe integer, got " + value);
    }
  }
  function numberToHexUnpadded(num) {
    const hex = abignumber(num).toString(16);
    return hex.length & 1 ? "0" + hex : hex;
  }
  function hexToNumber(hex) {
    if (typeof hex !== "string")
      throw new TypeError("hex string expected, got " + typeof hex);
    return hex === "" ? _0n : BigInt("0x" + hex);
  }
  function bytesToNumberBE(bytes) {
    return hexToNumber(bytesToHex(bytes));
  }
  function bytesToNumberLE(bytes) {
    return hexToNumber(bytesToHex(copyBytes(abytes(bytes)).reverse()));
  }
  function numberToBytesBE(n, len) {
    anumber2(len);
    if (len === 0)
      throw new RangeError("zero length");
    n = abignumber(n);
    const hex = n.toString(16);
    if (hex.length > len * 2)
      throw new RangeError("number too large");
    return hexToBytes(hex.padStart(len * 2, "0"));
  }
  function numberToBytesLE(n, len) {
    return numberToBytesBE(n, len).reverse();
  }
  function copyBytes(bytes) {
    return Uint8Array.from(abytes2(bytes));
  }
  var isPosBig = (n) => typeof n === "bigint" && _0n <= n;
  function inRange(n, min, max) {
    return isPosBig(n) && isPosBig(min) && isPosBig(max) && min <= n && n < max;
  }
  function aInRange(title, n, min, max) {
    if (!inRange(n, min, max))
      throw new RangeError("expected valid " + title + ": " + min + " <= n < " + max + ", got " + n);
  }
  function bitLen(n) {
    if (n < _0n)
      throw new Error("expected non-negative bigint, got " + n);
    let len;
    for (len = 0; n > _0n; n >>= _1n, len += 1)
      ;
    return len;
  }
  var bitMask = (n) => (_1n << BigInt(n)) - _1n;
  function createHmacDrbg(hashLen, qByteLen, hmacFn) {
    anumber2(hashLen, "hashLen");
    anumber2(qByteLen, "qByteLen");
    if (typeof hmacFn !== "function")
      throw new TypeError("hmacFn must be a function");
    const u8n = (len) => new Uint8Array(len);
    const NULL = Uint8Array.of();
    const byte0 = Uint8Array.of(0);
    const byte1 = Uint8Array.of(1);
    const _maxDrbgIters = 1e3;
    let v = u8n(hashLen);
    let k = u8n(hashLen);
    let i = 0;
    const reset = () => {
      v.fill(1);
      k.fill(0);
      i = 0;
    };
    const h = (...msgs) => hmacFn(k, concatBytes2(v, ...msgs));
    const reseed = (seed = NULL) => {
      k = h(byte0, seed);
      v = h();
      if (seed.length === 0)
        return;
      k = h(byte1, seed);
      v = h();
    };
    const gen = () => {
      if (i++ >= _maxDrbgIters)
        throw new Error("drbg: tried max amount of iterations");
      let len = 0;
      const out = [];
      while (len < qByteLen) {
        v = h();
        const sl = v.slice();
        out.push(sl);
        len += v.length;
      }
      return concatBytes2(...out);
    };
    const genUntil = (seed, pred) => {
      reset();
      reseed(seed);
      let res = void 0;
      while ((res = pred(gen())) === void 0)
        reseed();
      reset();
      return res;
    };
    return genUntil;
  }
  function validateObject(object, fields = {}, optFields = {}) {
    if (Object.prototype.toString.call(object) !== "[object Object]")
      throw new TypeError("expected valid options object");
    function checkField(fieldName, expectedType, isOpt) {
      if (!isOpt && expectedType !== "function" && !Object.hasOwn(object, fieldName))
        throw new TypeError(`param "${fieldName}" is invalid: expected own property`);
      const val = object[fieldName];
      if (isOpt && val === void 0)
        return;
      const current = typeof val;
      if (current !== expectedType || val === null)
        throw new TypeError(`param "${fieldName}" is invalid: expected ${expectedType}, got ${current}`);
    }
    const iter = (f, isOpt) => Object.entries(f).forEach(([k, v]) => checkField(k, v, isOpt));
    iter(fields, false);
    iter(optFields, true);
  }

  // node_modules/@noble/curves/abstract/modular.js
  var _0n2 = /* @__PURE__ */ BigInt(0);
  var _1n2 = /* @__PURE__ */ BigInt(1);
  var _2n = /* @__PURE__ */ BigInt(2);
  var _3n = /* @__PURE__ */ BigInt(3);
  var _4n = /* @__PURE__ */ BigInt(4);
  var _5n = /* @__PURE__ */ BigInt(5);
  var _7n = /* @__PURE__ */ BigInt(7);
  var _8n = /* @__PURE__ */ BigInt(8);
  var _9n = /* @__PURE__ */ BigInt(9);
  var _16n = /* @__PURE__ */ BigInt(16);
  function mod(a, b) {
    if (b <= _0n2)
      throw new Error("mod: expected positive modulus, got " + b);
    const result = a % b;
    return result >= _0n2 ? result : b + result;
  }
  function invert(number, modulo) {
    if (number === _0n2)
      throw new Error("invert: expected non-zero number");
    if (modulo <= _0n2)
      throw new Error("invert: expected positive modulus, got " + modulo);
    let a = mod(number, modulo);
    let b = modulo;
    let x = _0n2, y = _1n2, u = _1n2, v = _0n2;
    while (a !== _0n2) {
      const q = b / a;
      const r = b - a * q;
      const m = x - u * q;
      const n = y - v * q;
      b = a, a = r, x = u, y = v, u = m, v = n;
    }
    const gcd = b;
    if (gcd !== _1n2)
      throw new Error("invert: does not exist");
    return mod(x, modulo);
  }
  function assertIsSquare(Fp, root, n) {
    const F = Fp;
    if (!F.eql(F.sqr(root), n))
      throw new Error("Cannot find square root");
  }
  function sqrt3mod4(Fp, n) {
    const F = Fp;
    const p1div4 = (F.ORDER + _1n2) / _4n;
    const root = F.pow(n, p1div4);
    assertIsSquare(F, root, n);
    return root;
  }
  function sqrt5mod8(Fp, n) {
    const F = Fp;
    const p5div8 = (F.ORDER - _5n) / _8n;
    const n2 = F.mul(n, _2n);
    const v = F.pow(n2, p5div8);
    const nv = F.mul(n, v);
    const i = F.mul(F.mul(nv, _2n), v);
    const root = F.mul(nv, F.sub(i, F.ONE));
    assertIsSquare(F, root, n);
    return root;
  }
  function sqrt9mod16(P) {
    const Fp_ = Field(P);
    const tn = tonelliShanks(P);
    const c1 = tn(Fp_, Fp_.neg(Fp_.ONE));
    const c2 = tn(Fp_, c1);
    const c3 = tn(Fp_, Fp_.neg(c1));
    const c4 = (P + _7n) / _16n;
    return ((Fp, n) => {
      const F = Fp;
      let tv1 = F.pow(n, c4);
      let tv2 = F.mul(tv1, c1);
      const tv3 = F.mul(tv1, c2);
      const tv4 = F.mul(tv1, c3);
      const e1 = F.eql(F.sqr(tv2), n);
      const e2 = F.eql(F.sqr(tv3), n);
      tv1 = F.cmov(tv1, tv2, e1);
      tv2 = F.cmov(tv4, tv3, e2);
      const e3 = F.eql(F.sqr(tv2), n);
      const root = F.cmov(tv1, tv2, e3);
      assertIsSquare(F, root, n);
      return root;
    });
  }
  function tonelliShanks(P) {
    if (P < _3n)
      throw new Error("sqrt is not defined for small field");
    let Q = P - _1n2;
    let S = 0;
    while (Q % _2n === _0n2) {
      Q /= _2n;
      S++;
    }
    let Z = _2n;
    const _Fp = Field(P);
    while (FpLegendre(_Fp, Z) === 1) {
      if (Z++ > 1e3)
        throw new Error("Cannot find square root: probably non-prime P");
    }
    if (S === 1)
      return sqrt3mod4;
    let cc = _Fp.pow(Z, Q);
    const Q1div2 = (Q + _1n2) / _2n;
    return function tonelliSlow(Fp, n) {
      const F = Fp;
      if (F.is0(n))
        return n;
      if (FpLegendre(F, n) !== 1)
        throw new Error("Cannot find square root");
      let M = S;
      let c = F.mul(F.ONE, cc);
      let t = F.pow(n, Q);
      let R = F.pow(n, Q1div2);
      while (!F.eql(t, F.ONE)) {
        if (F.is0(t))
          return F.ZERO;
        let i = 1;
        let t_tmp = F.sqr(t);
        while (!F.eql(t_tmp, F.ONE)) {
          i++;
          t_tmp = F.sqr(t_tmp);
          if (i === M)
            throw new Error("Cannot find square root");
        }
        const exponent = _1n2 << BigInt(M - i - 1);
        const b = F.pow(c, exponent);
        M = i;
        c = F.sqr(b);
        t = F.mul(t, c);
        R = F.mul(R, b);
      }
      return R;
    };
  }
  function FpSqrt(P) {
    if (P % _4n === _3n)
      return sqrt3mod4;
    if (P % _8n === _5n)
      return sqrt5mod8;
    if (P % _16n === _9n)
      return sqrt9mod16(P);
    return tonelliShanks(P);
  }
  var FIELD_FIELDS = [
    "create",
    "isValid",
    "is0",
    "neg",
    "inv",
    "sqrt",
    "sqr",
    "eql",
    "add",
    "sub",
    "mul",
    "pow",
    "div",
    "addN",
    "subN",
    "mulN",
    "sqrN"
  ];
  function validateField(field) {
    const initial = {
      ORDER: "bigint",
      BYTES: "number",
      BITS: "number"
    };
    const opts = FIELD_FIELDS.reduce((map2, val) => {
      map2[val] = "function";
      return map2;
    }, initial);
    validateObject(field, opts);
    asafenumber(field.BYTES, "BYTES");
    asafenumber(field.BITS, "BITS");
    if (field.BYTES < 1 || field.BITS < 1)
      throw new Error("invalid field: expected BYTES/BITS > 0");
    if (field.ORDER <= _1n2)
      throw new Error("invalid field: expected ORDER > 1, got " + field.ORDER);
    return field;
  }
  function FpPow(Fp, num, power) {
    const F = Fp;
    if (power < _0n2)
      throw new Error("invalid exponent, negatives unsupported");
    if (power === _0n2)
      return F.ONE;
    if (power === _1n2)
      return num;
    let p = F.ONE;
    let d = num;
    while (power > _0n2) {
      if (power & _1n2)
        p = F.mul(p, d);
      d = F.sqr(d);
      power >>= _1n2;
    }
    return p;
  }
  function FpInvertBatch(Fp, nums, passZero = false) {
    const F = Fp;
    const inverted = new Array(nums.length).fill(passZero ? F.ZERO : void 0);
    const multipliedAcc = nums.reduce((acc, num, i) => {
      if (F.is0(num))
        return acc;
      inverted[i] = acc;
      return F.mul(acc, num);
    }, F.ONE);
    const invertedAcc = F.inv(multipliedAcc);
    nums.reduceRight((acc, num, i) => {
      if (F.is0(num))
        return acc;
      inverted[i] = F.mul(acc, inverted[i]);
      return F.mul(acc, num);
    }, invertedAcc);
    return inverted;
  }
  function FpLegendre(Fp, n) {
    const F = Fp;
    const p1mod2 = (F.ORDER - _1n2) / _2n;
    const powered = F.pow(n, p1mod2);
    const yes = F.eql(powered, F.ONE);
    const zero = F.eql(powered, F.ZERO);
    const no = F.eql(powered, F.neg(F.ONE));
    if (!yes && !zero && !no)
      throw new Error("invalid Legendre symbol result");
    return yes ? 1 : zero ? 0 : -1;
  }
  function nLength(n, nBitLength) {
    if (nBitLength !== void 0)
      anumber3(nBitLength);
    if (n <= _0n2)
      throw new Error("invalid n length: expected positive n, got " + n);
    if (nBitLength !== void 0 && nBitLength < 1)
      throw new Error("invalid n length: expected positive bit length, got " + nBitLength);
    const bits = bitLen(n);
    if (nBitLength !== void 0 && nBitLength < bits)
      throw new Error(`invalid n length: expected bit length (${bits}) >= n.length (${nBitLength})`);
    const _nBitLength = nBitLength !== void 0 ? nBitLength : bits;
    const nByteLength = Math.ceil(_nBitLength / 8);
    return { nBitLength: _nBitLength, nByteLength };
  }
  var FIELD_SQRT = /* @__PURE__ */ new WeakMap();
  var _Field = class {
    constructor(ORDER, opts = {}) {
      __publicField(this, "ORDER");
      __publicField(this, "BITS");
      __publicField(this, "BYTES");
      __publicField(this, "isLE");
      __publicField(this, "ZERO", _0n2);
      __publicField(this, "ONE", _1n2);
      __publicField(this, "_lengths");
      __publicField(this, "_mod");
      if (ORDER <= _1n2)
        throw new Error("invalid field: expected ORDER > 1, got " + ORDER);
      let _nbitLength = void 0;
      this.isLE = false;
      if (opts != null && typeof opts === "object") {
        if (typeof opts.BITS === "number")
          _nbitLength = opts.BITS;
        if (typeof opts.sqrt === "function")
          Object.defineProperty(this, "sqrt", { value: opts.sqrt, enumerable: true });
        if (typeof opts.isLE === "boolean")
          this.isLE = opts.isLE;
        if (opts.allowedLengths)
          this._lengths = Object.freeze(opts.allowedLengths.slice());
        if (typeof opts.modFromBytes === "boolean")
          this._mod = opts.modFromBytes;
      }
      const { nBitLength, nByteLength } = nLength(ORDER, _nbitLength);
      if (nByteLength > 2048)
        throw new Error("invalid field: expected ORDER of <= 2048 bytes");
      this.ORDER = ORDER;
      this.BITS = nBitLength;
      this.BYTES = nByteLength;
      Object.freeze(this);
    }
    create(num) {
      return mod(num, this.ORDER);
    }
    isValid(num) {
      if (typeof num !== "bigint")
        throw new TypeError("invalid field element: expected bigint, got " + typeof num);
      return _0n2 <= num && num < this.ORDER;
    }
    is0(num) {
      return num === _0n2;
    }
    // is valid and invertible
    isValidNot0(num) {
      return !this.is0(num) && this.isValid(num);
    }
    isOdd(num) {
      return (num & _1n2) === _1n2;
    }
    neg(num) {
      return mod(-num, this.ORDER);
    }
    eql(lhs, rhs) {
      return lhs === rhs;
    }
    sqr(num) {
      return mod(num * num, this.ORDER);
    }
    add(lhs, rhs) {
      return mod(lhs + rhs, this.ORDER);
    }
    sub(lhs, rhs) {
      return mod(lhs - rhs, this.ORDER);
    }
    mul(lhs, rhs) {
      return mod(lhs * rhs, this.ORDER);
    }
    pow(num, power) {
      return FpPow(this, num, power);
    }
    div(lhs, rhs) {
      return mod(lhs * invert(rhs, this.ORDER), this.ORDER);
    }
    // Same as above, but doesn't normalize
    sqrN(num) {
      return num * num;
    }
    addN(lhs, rhs) {
      return lhs + rhs;
    }
    subN(lhs, rhs) {
      return lhs - rhs;
    }
    mulN(lhs, rhs) {
      return lhs * rhs;
    }
    inv(num) {
      return invert(num, this.ORDER);
    }
    sqrt(num) {
      let sqrt = FIELD_SQRT.get(this);
      if (!sqrt)
        FIELD_SQRT.set(this, sqrt = FpSqrt(this.ORDER));
      return sqrt(this, num);
    }
    toBytes(num) {
      return this.isLE ? numberToBytesLE(num, this.BYTES) : numberToBytesBE(num, this.BYTES);
    }
    fromBytes(bytes, skipValidation = false) {
      abytes2(bytes);
      const { _lengths: allowedLengths, BYTES, isLE: isLE2, ORDER, _mod: modFromBytes } = this;
      if (allowedLengths) {
        if (bytes.length < 1 || !allowedLengths.includes(bytes.length) || bytes.length > BYTES) {
          throw new Error("Field.fromBytes: expected " + allowedLengths + " bytes, got " + bytes.length);
        }
        const padded = new Uint8Array(BYTES);
        padded.set(bytes, isLE2 ? 0 : padded.length - bytes.length);
        bytes = padded;
      }
      if (bytes.length !== BYTES)
        throw new Error("Field.fromBytes: expected " + BYTES + " bytes, got " + bytes.length);
      let scalar = isLE2 ? bytesToNumberLE(bytes) : bytesToNumberBE(bytes);
      if (modFromBytes)
        scalar = mod(scalar, ORDER);
      if (!skipValidation) {
        if (!this.isValid(scalar))
          throw new Error("invalid field element: outside of range 0..ORDER");
      }
      return scalar;
    }
    // TODO: we don't need it here, move out to separate fn
    invertBatch(lst) {
      return FpInvertBatch(this, lst);
    }
    // We can't move this out because Fp6, Fp12 implement it
    // and it's unclear what to return in there.
    cmov(a, b, condition) {
      abool(condition, "condition");
      return condition ? b : a;
    }
  };
  Object.freeze(_Field.prototype);
  function Field(ORDER, opts = {}) {
    return new _Field(ORDER, opts);
  }
  function getFieldBytesLength(fieldOrder) {
    if (typeof fieldOrder !== "bigint")
      throw new Error("field order must be bigint");
    if (fieldOrder <= _1n2)
      throw new Error("field order must be greater than 1");
    const bitLength = bitLen(fieldOrder - _1n2);
    return Math.ceil(bitLength / 8);
  }
  function getMinHashLength(fieldOrder) {
    const length = getFieldBytesLength(fieldOrder);
    return length + Math.ceil(length / 2);
  }
  function mapHashToField(key, fieldOrder, isLE2 = false) {
    abytes2(key);
    const len = key.length;
    const fieldLen = getFieldBytesLength(fieldOrder);
    const minLen = Math.max(getMinHashLength(fieldOrder), 16);
    if (len < minLen || len > 1024)
      throw new Error("expected " + minLen + "-1024 bytes of input, got " + len);
    const num = isLE2 ? bytesToNumberLE(key) : bytesToNumberBE(key);
    const reduced = mod(num, fieldOrder - _1n2) + _1n2;
    return isLE2 ? numberToBytesLE(reduced, fieldLen) : numberToBytesBE(reduced, fieldLen);
  }

  // node_modules/@noble/curves/abstract/curve.js
  var _0n3 = /* @__PURE__ */ BigInt(0);
  var _1n3 = /* @__PURE__ */ BigInt(1);
  function negateCt(condition, item) {
    const neg = item.negate();
    return condition ? neg : item;
  }
  function normalizeZ(c, points) {
    const invertedZs = FpInvertBatch(c.Fp, points.map((p) => p.Z));
    return points.map((p, i) => c.fromAffine(p.toAffine(invertedZs[i])));
  }
  function validateW(W, bits) {
    if (!Number.isSafeInteger(W) || W <= 0 || W > bits)
      throw new Error("invalid window size, expected [1.." + bits + "], got W=" + W);
  }
  function calcWOpts(W, scalarBits) {
    validateW(W, scalarBits);
    const windows = Math.ceil(scalarBits / W) + 1;
    const windowSize = 2 ** (W - 1);
    const maxNumber = 2 ** W;
    const mask = bitMask(W);
    const shiftBy = BigInt(W);
    return { windows, windowSize, mask, maxNumber, shiftBy };
  }
  function calcOffsets(n, window2, wOpts) {
    const { windowSize, mask, maxNumber, shiftBy } = wOpts;
    let wbits = Number(n & mask);
    let nextN = n >> shiftBy;
    if (wbits > windowSize) {
      wbits -= maxNumber;
      nextN += _1n3;
    }
    const offsetStart = window2 * windowSize;
    const offset = offsetStart + Math.abs(wbits) - 1;
    const isZero = wbits === 0;
    const isNeg = wbits < 0;
    const isNegF = window2 % 2 !== 0;
    const offsetF = offsetStart;
    return { nextN, offset, isZero, isNeg, isNegF, offsetF };
  }
  var pointPrecomputes = /* @__PURE__ */ new WeakMap();
  var pointWindowSizes = /* @__PURE__ */ new WeakMap();
  function getW(P) {
    return pointWindowSizes.get(P) || 1;
  }
  function assert0(n) {
    if (n !== _0n3)
      throw new Error("invalid wNAF");
  }
  var wNAF = class {
    // Parametrized with a given Point class (not individual point)
    constructor(Point, bits) {
      __publicField(this, "BASE");
      __publicField(this, "ZERO");
      __publicField(this, "Fn");
      __publicField(this, "bits");
      this.BASE = Point.BASE;
      this.ZERO = Point.ZERO;
      this.Fn = Point.Fn;
      this.bits = bits;
    }
    // non-const time multiplication ladder
    _unsafeLadder(elm, n, p = this.ZERO) {
      let d = elm;
      while (n > _0n3) {
        if (n & _1n3)
          p = p.add(d);
        d = d.double();
        n >>= _1n3;
      }
      return p;
    }
    /**
     * Creates a wNAF precomputation window. Used for caching.
     * Default window size is set by `utils.precompute()` and is equal to 8.
     * Number of precomputed points depends on the curve size:
     * 2^(𝑊−1) * (Math.ceil(𝑛 / 𝑊) + 1), where:
     * - 𝑊 is the window size
     * - 𝑛 is the bitlength of the curve order.
     * For a 256-bit curve and window size 8, the number of precomputed points is 128 * 33 = 4224.
     * @param point - Point instance
     * @param W - window size
     * @returns precomputed point tables flattened to a single array
     */
    precomputeWindow(point, W) {
      const { windows, windowSize } = calcWOpts(W, this.bits);
      const points = [];
      let p = point;
      let base = p;
      for (let window2 = 0; window2 < windows; window2++) {
        base = p;
        points.push(base);
        for (let i = 1; i < windowSize; i++) {
          base = base.add(p);
          points.push(base);
        }
        p = base.double();
      }
      return points;
    }
    /**
     * Implements ec multiplication using precomputed tables and w-ary non-adjacent form.
     * More compact implementation:
     * https://github.com/paulmillr/noble-secp256k1/blob/47cb1669b6e506ad66b35fe7d76132ae97465da2/index.ts#L502-L541
     * @returns real and fake (for const-time) points
     */
    wNAF(W, precomputes, n) {
      if (!this.Fn.isValid(n))
        throw new Error("invalid scalar");
      let p = this.ZERO;
      let f = this.BASE;
      const wo = calcWOpts(W, this.bits);
      for (let window2 = 0; window2 < wo.windows; window2++) {
        const { nextN, offset, isZero, isNeg, isNegF, offsetF } = calcOffsets(n, window2, wo);
        n = nextN;
        if (isZero) {
          f = f.add(negateCt(isNegF, precomputes[offsetF]));
        } else {
          p = p.add(negateCt(isNeg, precomputes[offset]));
        }
      }
      assert0(n);
      return { p, f };
    }
    /**
     * Implements unsafe EC multiplication using precomputed tables
     * and w-ary non-adjacent form.
     * @param acc - accumulator point to add result of multiplication
     * @returns point
     */
    wNAFUnsafe(W, precomputes, n, acc = this.ZERO) {
      const wo = calcWOpts(W, this.bits);
      for (let window2 = 0; window2 < wo.windows; window2++) {
        if (n === _0n3)
          break;
        const { nextN, offset, isZero, isNeg } = calcOffsets(n, window2, wo);
        n = nextN;
        if (isZero) {
          continue;
        } else {
          const item = precomputes[offset];
          acc = acc.add(isNeg ? item.negate() : item);
        }
      }
      assert0(n);
      return acc;
    }
    getPrecomputes(W, point, transform) {
      let comp = pointPrecomputes.get(point);
      if (!comp) {
        comp = this.precomputeWindow(point, W);
        if (W !== 1) {
          if (typeof transform === "function")
            comp = transform(comp);
          pointPrecomputes.set(point, comp);
        }
      }
      return comp;
    }
    cached(point, scalar, transform) {
      const W = getW(point);
      return this.wNAF(W, this.getPrecomputes(W, point, transform), scalar);
    }
    unsafe(point, scalar, transform, prev) {
      const W = getW(point);
      if (W === 1)
        return this._unsafeLadder(point, scalar, prev);
      return this.wNAFUnsafe(W, this.getPrecomputes(W, point, transform), scalar, prev);
    }
    // We calculate precomputes for elliptic curve point multiplication
    // using windowed method. This specifies window size and
    // stores precomputed values. Usually only base point would be precomputed.
    createCache(P, W) {
      validateW(W, this.bits);
      pointWindowSizes.set(P, W);
      pointPrecomputes.delete(P);
    }
    hasCache(elm) {
      return getW(elm) !== 1;
    }
  };
  function mulEndoUnsafe(Point, point, k1, k2) {
    let acc = point;
    let p1 = Point.ZERO;
    let p2 = Point.ZERO;
    while (k1 > _0n3 || k2 > _0n3) {
      if (k1 & _1n3)
        p1 = p1.add(acc);
      if (k2 & _1n3)
        p2 = p2.add(acc);
      acc = acc.double();
      k1 >>= _1n3;
      k2 >>= _1n3;
    }
    return { p1, p2 };
  }
  function createField(order, field, isLE2) {
    if (field) {
      if (field.ORDER !== order)
        throw new Error("Field.ORDER must match order: Fp == p, Fn == n");
      validateField(field);
      return field;
    } else {
      return Field(order, { isLE: isLE2 });
    }
  }
  function createCurveFields(type, CURVE, curveOpts = {}, FpFnLE) {
    if (FpFnLE === void 0)
      FpFnLE = type === "edwards";
    if (!CURVE || typeof CURVE !== "object")
      throw new Error(`expected valid ${type} CURVE object`);
    for (const p of ["p", "n", "h"]) {
      const val = CURVE[p];
      if (!(typeof val === "bigint" && val > _0n3))
        throw new Error(`CURVE.${p} must be positive bigint`);
    }
    const Fp = createField(CURVE.p, curveOpts.Fp, FpFnLE);
    const Fn = createField(CURVE.n, curveOpts.Fn, FpFnLE);
    const _b = type === "weierstrass" ? "b" : "d";
    const params = ["Gx", "Gy", "a", _b];
    for (const p of params) {
      if (!Fp.isValid(CURVE[p]))
        throw new Error(`CURVE.${p} must be valid field element of CURVE.Fp`);
    }
    CURVE = Object.freeze(Object.assign({}, CURVE));
    return { CURVE, Fp, Fn };
  }
  function createKeygen(randomSecretKey, getPublicKey) {
    return function keygen(seed) {
      const secretKey = randomSecretKey(seed);
      return { secretKey, publicKey: getPublicKey(secretKey) };
    };
  }

  // node_modules/@noble/hashes/hmac.js
  var _HMAC = class {
    constructor(hash, key) {
      __publicField(this, "oHash");
      __publicField(this, "iHash");
      __publicField(this, "blockLen");
      __publicField(this, "outputLen");
      __publicField(this, "canXOF", false);
      __publicField(this, "finished", false);
      __publicField(this, "destroyed", false);
      ahash(hash);
      abytes(key, void 0, "key");
      this.iHash = hash.create();
      if (typeof this.iHash.update !== "function")
        throw new Error("Expected instance of class which extends utils.Hash");
      this.blockLen = this.iHash.blockLen;
      this.outputLen = this.iHash.outputLen;
      const blockLen = this.blockLen;
      const pad = new Uint8Array(blockLen);
      pad.set(key.length > blockLen ? hash.create().update(key).digest() : key);
      for (let i = 0; i < pad.length; i++)
        pad[i] ^= 54;
      this.iHash.update(pad);
      this.oHash = hash.create();
      for (let i = 0; i < pad.length; i++)
        pad[i] ^= 54 ^ 92;
      this.oHash.update(pad);
      clean(pad);
    }
    update(buf) {
      aexists(this);
      this.iHash.update(buf);
      return this;
    }
    digestInto(out) {
      aexists(this);
      aoutput(out, this);
      this.finished = true;
      const buf = out.subarray(0, this.outputLen);
      this.iHash.digestInto(buf);
      this.oHash.update(buf);
      this.oHash.digestInto(buf);
      this.destroy();
    }
    digest() {
      const out = new Uint8Array(this.oHash.outputLen);
      this.digestInto(out);
      return out;
    }
    _cloneInto(to) {
      to || (to = Object.create(Object.getPrototypeOf(this), {}));
      const { oHash, iHash, finished, destroyed, blockLen, outputLen } = this;
      to = to;
      to.finished = finished;
      to.destroyed = destroyed;
      to.blockLen = blockLen;
      to.outputLen = outputLen;
      to.oHash = oHash._cloneInto(to.oHash);
      to.iHash = iHash._cloneInto(to.iHash);
      return to;
    }
    clone() {
      return this._cloneInto();
    }
    destroy() {
      this.destroyed = true;
      this.oHash.destroy();
      this.iHash.destroy();
    }
  };
  var hmac = /* @__PURE__ */ (() => {
    const hmac_ = ((hash, key, message) => new _HMAC(hash, key).update(message).digest());
    hmac_.create = (hash, key) => new _HMAC(hash, key);
    return hmac_;
  })();

  // node_modules/@noble/curves/abstract/weierstrass.js
  var divNearest = (num, den) => (num + (num >= 0 ? den : -den) / _2n2) / den;
  function _splitEndoScalar(k, basis, n) {
    aInRange("scalar", k, _0n4, n);
    const [[a1, b1], [a2, b2]] = basis;
    const c1 = divNearest(b2 * k, n);
    const c2 = divNearest(-b1 * k, n);
    let k1 = k - c1 * a1 - c2 * a2;
    let k2 = -c1 * b1 - c2 * b2;
    const k1neg = k1 < _0n4;
    const k2neg = k2 < _0n4;
    if (k1neg)
      k1 = -k1;
    if (k2neg)
      k2 = -k2;
    const MAX_NUM = bitMask(Math.ceil(bitLen(n) / 2)) + _1n4;
    if (k1 < _0n4 || k1 >= MAX_NUM || k2 < _0n4 || k2 >= MAX_NUM) {
      throw new Error("splitScalar (endomorphism): failed for k");
    }
    return { k1neg, k1, k2neg, k2 };
  }
  function validateSigFormat(format) {
    if (!["compact", "recovered", "der"].includes(format))
      throw new Error('Signature format must be "compact", "recovered", or "der"');
    return format;
  }
  function validateSigOpts(opts, def) {
    validateObject(opts);
    const optsn = {};
    for (let optName of Object.keys(def)) {
      optsn[optName] = opts[optName] === void 0 ? def[optName] : opts[optName];
    }
    abool(optsn.lowS, "lowS");
    abool(optsn.prehash, "prehash");
    if (optsn.format !== void 0)
      validateSigFormat(optsn.format);
    return optsn;
  }
  var DERErr = class extends Error {
    constructor(m = "") {
      super(m);
    }
  };
  var DER = {
    // asn.1 DER encoding utils
    Err: DERErr,
    // Basic building block is TLV (Tag-Length-Value)
    _tlv: {
      encode: (tag, data) => {
        const { Err: E } = DER;
        asafenumber(tag, "tag");
        if (tag < 0 || tag > 255)
          throw new E("tlv.encode: wrong tag");
        if (typeof data !== "string")
          throw new TypeError('"data" expected string, got type=' + typeof data);
        if (data.length & 1)
          throw new E("tlv.encode: unpadded data");
        const dataLen = data.length / 2;
        const len = numberToHexUnpadded(dataLen);
        if (len.length / 2 & 128)
          throw new E("tlv.encode: long form length too big");
        const lenLen = dataLen > 127 ? numberToHexUnpadded(len.length / 2 | 128) : "";
        const t = numberToHexUnpadded(tag);
        return t + lenLen + len + data;
      },
      // v - value, l - left bytes (unparsed)
      decode(tag, data) {
        const { Err: E } = DER;
        data = abytes2(data, void 0, "DER data");
        let pos = 0;
        if (tag < 0 || tag > 255)
          throw new E("tlv.encode: wrong tag");
        if (data.length < 2 || data[pos++] !== tag)
          throw new E("tlv.decode: wrong tlv");
        const first = data[pos++];
        const isLong = !!(first & 128);
        let length = 0;
        if (!isLong)
          length = first;
        else {
          const lenLen = first & 127;
          if (!lenLen)
            throw new E("tlv.decode(long): indefinite length not supported");
          if (lenLen > 4)
            throw new E("tlv.decode(long): byte length is too big");
          const lengthBytes = data.subarray(pos, pos + lenLen);
          if (lengthBytes.length !== lenLen)
            throw new E("tlv.decode: length bytes not complete");
          if (lengthBytes[0] === 0)
            throw new E("tlv.decode(long): zero leftmost byte");
          for (const b of lengthBytes)
            length = length << 8 | b;
          pos += lenLen;
          if (length < 128)
            throw new E("tlv.decode(long): not minimal encoding");
        }
        const v = data.subarray(pos, pos + length);
        if (v.length !== length)
          throw new E("tlv.decode: wrong value length");
        return { v, l: data.subarray(pos + length) };
      }
    },
    // https://crypto.stackexchange.com/a/57734 Leftmost bit of first byte is 'negative' flag,
    // since we always use positive integers here. It must always be empty:
    // - add zero byte if exists
    // - if next byte doesn't have a flag, leading zero is not allowed (minimal encoding)
    _int: {
      encode(num) {
        const { Err: E } = DER;
        abignumber(num);
        if (num < _0n4)
          throw new E("integer: negative integers are not allowed");
        let hex = numberToHexUnpadded(num);
        if (Number.parseInt(hex[0], 16) & 8)
          hex = "00" + hex;
        if (hex.length & 1)
          throw new E("unexpected DER parsing assertion: unpadded hex");
        return hex;
      },
      decode(data) {
        const { Err: E } = DER;
        if (data.length < 1)
          throw new E("invalid signature integer: empty");
        if (data[0] & 128)
          throw new E("invalid signature integer: negative");
        if (data.length > 1 && data[0] === 0 && !(data[1] & 128))
          throw new E("invalid signature integer: unnecessary leading zero");
        return bytesToNumberBE(data);
      }
    },
    toSig(bytes) {
      const { Err: E, _int: int, _tlv: tlv } = DER;
      const data = abytes2(bytes, void 0, "signature");
      const { v: seqBytes, l: seqLeftBytes } = tlv.decode(48, data);
      if (seqLeftBytes.length)
        throw new E("invalid signature: left bytes after parsing");
      const { v: rBytes, l: rLeftBytes } = tlv.decode(2, seqBytes);
      const { v: sBytes, l: sLeftBytes } = tlv.decode(2, rLeftBytes);
      if (sLeftBytes.length)
        throw new E("invalid signature: left bytes after parsing");
      return { r: int.decode(rBytes), s: int.decode(sBytes) };
    },
    hexFromSig(sig) {
      const { _tlv: tlv, _int: int } = DER;
      const rs = tlv.encode(2, int.encode(sig.r));
      const ss = tlv.encode(2, int.encode(sig.s));
      const seq = rs + ss;
      return tlv.encode(48, seq);
    }
  };
  Object.freeze(DER._tlv);
  Object.freeze(DER._int);
  Object.freeze(DER);
  var _0n4 = /* @__PURE__ */ BigInt(0);
  var _1n4 = /* @__PURE__ */ BigInt(1);
  var _2n2 = /* @__PURE__ */ BigInt(2);
  var _3n2 = /* @__PURE__ */ BigInt(3);
  var _4n2 = /* @__PURE__ */ BigInt(4);
  function weierstrass(params, extraOpts = {}) {
    const validated = createCurveFields("weierstrass", params, extraOpts);
    const Fp = validated.Fp;
    const Fn = validated.Fn;
    let CURVE = validated.CURVE;
    const { h: cofactor, n: CURVE_ORDER } = CURVE;
    validateObject(extraOpts, {}, {
      allowInfinityPoint: "boolean",
      clearCofactor: "function",
      isTorsionFree: "function",
      fromBytes: "function",
      toBytes: "function",
      endo: "object"
    });
    const { endo, allowInfinityPoint } = extraOpts;
    if (endo) {
      if (!Fp.is0(CURVE.a) || typeof endo.beta !== "bigint" || !Array.isArray(endo.basises)) {
        throw new Error('invalid endo: expected "beta": bigint and "basises": array');
      }
    }
    const lengths = getWLengths(Fp, Fn);
    function assertCompressionIsSupported() {
      if (!Fp.isOdd)
        throw new Error("compression is not supported: Field does not have .isOdd()");
    }
    function pointToBytes(_c, point, isCompressed) {
      if (allowInfinityPoint && point.is0())
        return Uint8Array.of(0);
      const { x, y } = point.toAffine();
      const bx = Fp.toBytes(x);
      abool(isCompressed, "isCompressed");
      if (isCompressed) {
        assertCompressionIsSupported();
        const hasEvenY = !Fp.isOdd(y);
        return concatBytes2(pprefix(hasEvenY), bx);
      } else {
        return concatBytes2(Uint8Array.of(4), bx, Fp.toBytes(y));
      }
    }
    function pointFromBytes(bytes) {
      abytes2(bytes, void 0, "Point");
      const { publicKey: comp, publicKeyUncompressed: uncomp } = lengths;
      const length = bytes.length;
      const head = bytes[0];
      const tail = bytes.subarray(1);
      if (allowInfinityPoint && length === 1 && head === 0)
        return { x: Fp.ZERO, y: Fp.ZERO };
      if (length === comp && (head === 2 || head === 3)) {
        const x = Fp.fromBytes(tail);
        if (!Fp.isValid(x))
          throw new Error("bad point: is not on curve, wrong x");
        const y2 = weierstrassEquation(x);
        let y;
        try {
          y = Fp.sqrt(y2);
        } catch (sqrtError) {
          const err = sqrtError instanceof Error ? ": " + sqrtError.message : "";
          throw new Error("bad point: is not on curve, sqrt error" + err);
        }
        assertCompressionIsSupported();
        const evenY = Fp.isOdd(y);
        const evenH = (head & 1) === 1;
        if (evenH !== evenY)
          y = Fp.neg(y);
        return { x, y };
      } else if (length === uncomp && head === 4) {
        const L = Fp.BYTES;
        const x = Fp.fromBytes(tail.subarray(0, L));
        const y = Fp.fromBytes(tail.subarray(L, L * 2));
        if (!isValidXY(x, y))
          throw new Error("bad point: is not on curve");
        return { x, y };
      } else {
        throw new Error(`bad point: got length ${length}, expected compressed=${comp} or uncompressed=${uncomp}`);
      }
    }
    const encodePoint = extraOpts.toBytes === void 0 ? pointToBytes : extraOpts.toBytes;
    const decodePoint = extraOpts.fromBytes === void 0 ? pointFromBytes : extraOpts.fromBytes;
    function weierstrassEquation(x) {
      const x2 = Fp.sqr(x);
      const x3 = Fp.mul(x2, x);
      return Fp.add(Fp.add(x3, Fp.mul(x, CURVE.a)), CURVE.b);
    }
    function isValidXY(x, y) {
      const left = Fp.sqr(y);
      const right = weierstrassEquation(x);
      return Fp.eql(left, right);
    }
    if (!isValidXY(CURVE.Gx, CURVE.Gy))
      throw new Error("bad curve params: generator point");
    const _4a3 = Fp.mul(Fp.pow(CURVE.a, _3n2), _4n2);
    const _27b2 = Fp.mul(Fp.sqr(CURVE.b), BigInt(27));
    if (Fp.is0(Fp.add(_4a3, _27b2)))
      throw new Error("bad curve params: a or b");
    function acoord(title, n, banZero = false) {
      if (!Fp.isValid(n) || banZero && Fp.is0(n))
        throw new Error(`bad point coordinate ${title}`);
      return n;
    }
    function aprjpoint(other) {
      if (!(other instanceof Point))
        throw new Error("Weierstrass Point expected");
    }
    function splitEndoScalarN(k) {
      if (!endo || !endo.basises)
        throw new Error("no endo");
      return _splitEndoScalar(k, endo.basises, Fn.ORDER);
    }
    function finishEndo(endoBeta, k1p, k2p, k1neg, k2neg) {
      k2p = new Point(Fp.mul(k2p.X, endoBeta), k2p.Y, k2p.Z);
      k1p = negateCt(k1neg, k1p);
      k2p = negateCt(k2neg, k2p);
      return k1p.add(k2p);
    }
    const _Point = class _Point {
      /** Does NOT validate if the point is valid. Use `.assertValidity()`. */
      constructor(X, Y, Z) {
        __publicField(this, "X");
        __publicField(this, "Y");
        __publicField(this, "Z");
        this.X = acoord("x", X);
        this.Y = acoord("y", Y, true);
        this.Z = acoord("z", Z);
        Object.freeze(this);
      }
      static CURVE() {
        return CURVE;
      }
      /** Does NOT validate if the point is valid. Use `.assertValidity()`. */
      static fromAffine(p) {
        const { x, y } = p || {};
        if (!p || !Fp.isValid(x) || !Fp.isValid(y))
          throw new Error("invalid affine point");
        if (p instanceof _Point)
          throw new Error("projective point not allowed");
        if (Fp.is0(x) && Fp.is0(y))
          return _Point.ZERO;
        return new _Point(x, y, Fp.ONE);
      }
      static fromBytes(bytes) {
        const P = _Point.fromAffine(decodePoint(abytes2(bytes, void 0, "point")));
        P.assertValidity();
        return P;
      }
      static fromHex(hex) {
        return _Point.fromBytes(hexToBytes2(hex));
      }
      get x() {
        return this.toAffine().x;
      }
      get y() {
        return this.toAffine().y;
      }
      /**
       *
       * @param windowSize
       * @param isLazy - true will defer table computation until the first multiplication
       * @returns
       */
      precompute(windowSize = 8, isLazy = true) {
        wnaf.createCache(this, windowSize);
        if (!isLazy)
          this.multiply(_3n2);
        return this;
      }
      // TODO: return `this`
      /** A point on curve is valid if it conforms to equation. */
      assertValidity() {
        const p = this;
        if (p.is0()) {
          if (extraOpts.allowInfinityPoint && Fp.is0(p.X) && Fp.eql(p.Y, Fp.ONE) && Fp.is0(p.Z))
            return;
          throw new Error("bad point: ZERO");
        }
        const { x, y } = p.toAffine();
        if (!Fp.isValid(x) || !Fp.isValid(y))
          throw new Error("bad point: x or y not field elements");
        if (!isValidXY(x, y))
          throw new Error("bad point: equation left != right");
        if (!p.isTorsionFree())
          throw new Error("bad point: not in prime-order subgroup");
      }
      hasEvenY() {
        const { y } = this.toAffine();
        if (!Fp.isOdd)
          throw new Error("Field doesn't support isOdd");
        return !Fp.isOdd(y);
      }
      /** Compare one point to another. */
      equals(other) {
        aprjpoint(other);
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = other;
        const U1 = Fp.eql(Fp.mul(X1, Z2), Fp.mul(X2, Z1));
        const U2 = Fp.eql(Fp.mul(Y1, Z2), Fp.mul(Y2, Z1));
        return U1 && U2;
      }
      /** Flips point to one corresponding to (x, -y) in Affine coordinates. */
      negate() {
        return new _Point(this.X, Fp.neg(this.Y), this.Z);
      }
      // Renes-Costello-Batina exception-free doubling formula.
      // There is 30% faster Jacobian formula, but it is not complete.
      // https://eprint.iacr.org/2015/1060, algorithm 3
      // Cost: 8M + 3S + 3*a + 2*b3 + 15add.
      double() {
        const { a, b } = CURVE;
        const b3 = Fp.mul(b, _3n2);
        const { X: X1, Y: Y1, Z: Z1 } = this;
        let X3 = Fp.ZERO, Y3 = Fp.ZERO, Z3 = Fp.ZERO;
        let t0 = Fp.mul(X1, X1);
        let t1 = Fp.mul(Y1, Y1);
        let t2 = Fp.mul(Z1, Z1);
        let t3 = Fp.mul(X1, Y1);
        t3 = Fp.add(t3, t3);
        Z3 = Fp.mul(X1, Z1);
        Z3 = Fp.add(Z3, Z3);
        X3 = Fp.mul(a, Z3);
        Y3 = Fp.mul(b3, t2);
        Y3 = Fp.add(X3, Y3);
        X3 = Fp.sub(t1, Y3);
        Y3 = Fp.add(t1, Y3);
        Y3 = Fp.mul(X3, Y3);
        X3 = Fp.mul(t3, X3);
        Z3 = Fp.mul(b3, Z3);
        t2 = Fp.mul(a, t2);
        t3 = Fp.sub(t0, t2);
        t3 = Fp.mul(a, t3);
        t3 = Fp.add(t3, Z3);
        Z3 = Fp.add(t0, t0);
        t0 = Fp.add(Z3, t0);
        t0 = Fp.add(t0, t2);
        t0 = Fp.mul(t0, t3);
        Y3 = Fp.add(Y3, t0);
        t2 = Fp.mul(Y1, Z1);
        t2 = Fp.add(t2, t2);
        t0 = Fp.mul(t2, t3);
        X3 = Fp.sub(X3, t0);
        Z3 = Fp.mul(t2, t1);
        Z3 = Fp.add(Z3, Z3);
        Z3 = Fp.add(Z3, Z3);
        return new _Point(X3, Y3, Z3);
      }
      // Renes-Costello-Batina exception-free addition formula.
      // There is 30% faster Jacobian formula, but it is not complete.
      // https://eprint.iacr.org/2015/1060, algorithm 1
      // Cost: 12M + 0S + 3*a + 3*b3 + 23add.
      add(other) {
        aprjpoint(other);
        const { X: X1, Y: Y1, Z: Z1 } = this;
        const { X: X2, Y: Y2, Z: Z2 } = other;
        let X3 = Fp.ZERO, Y3 = Fp.ZERO, Z3 = Fp.ZERO;
        const a = CURVE.a;
        const b3 = Fp.mul(CURVE.b, _3n2);
        let t0 = Fp.mul(X1, X2);
        let t1 = Fp.mul(Y1, Y2);
        let t2 = Fp.mul(Z1, Z2);
        let t3 = Fp.add(X1, Y1);
        let t4 = Fp.add(X2, Y2);
        t3 = Fp.mul(t3, t4);
        t4 = Fp.add(t0, t1);
        t3 = Fp.sub(t3, t4);
        t4 = Fp.add(X1, Z1);
        let t5 = Fp.add(X2, Z2);
        t4 = Fp.mul(t4, t5);
        t5 = Fp.add(t0, t2);
        t4 = Fp.sub(t4, t5);
        t5 = Fp.add(Y1, Z1);
        X3 = Fp.add(Y2, Z2);
        t5 = Fp.mul(t5, X3);
        X3 = Fp.add(t1, t2);
        t5 = Fp.sub(t5, X3);
        Z3 = Fp.mul(a, t4);
        X3 = Fp.mul(b3, t2);
        Z3 = Fp.add(X3, Z3);
        X3 = Fp.sub(t1, Z3);
        Z3 = Fp.add(t1, Z3);
        Y3 = Fp.mul(X3, Z3);
        t1 = Fp.add(t0, t0);
        t1 = Fp.add(t1, t0);
        t2 = Fp.mul(a, t2);
        t4 = Fp.mul(b3, t4);
        t1 = Fp.add(t1, t2);
        t2 = Fp.sub(t0, t2);
        t2 = Fp.mul(a, t2);
        t4 = Fp.add(t4, t2);
        t0 = Fp.mul(t1, t4);
        Y3 = Fp.add(Y3, t0);
        t0 = Fp.mul(t5, t4);
        X3 = Fp.mul(t3, X3);
        X3 = Fp.sub(X3, t0);
        t0 = Fp.mul(t3, t1);
        Z3 = Fp.mul(t5, Z3);
        Z3 = Fp.add(Z3, t0);
        return new _Point(X3, Y3, Z3);
      }
      subtract(other) {
        aprjpoint(other);
        return this.add(other.negate());
      }
      is0() {
        return this.equals(_Point.ZERO);
      }
      /**
       * Constant time multiplication.
       * Uses wNAF method. Windowed method may be 10% faster,
       * but takes 2x longer to generate and consumes 2x memory.
       * Uses precomputes when available.
       * Uses endomorphism for Koblitz curves.
       * @param scalar - by which the point would be multiplied
       * @returns New point
       */
      multiply(scalar) {
        const { endo: endo2 } = extraOpts;
        if (!Fn.isValidNot0(scalar))
          throw new RangeError("invalid scalar: out of range");
        let point, fake;
        const mul = (n) => wnaf.cached(this, n, (p) => normalizeZ(_Point, p));
        if (endo2) {
          const { k1neg, k1, k2neg, k2 } = splitEndoScalarN(scalar);
          const { p: k1p, f: k1f } = mul(k1);
          const { p: k2p, f: k2f } = mul(k2);
          fake = k1f.add(k2f);
          point = finishEndo(endo2.beta, k1p, k2p, k1neg, k2neg);
        } else {
          const { p, f } = mul(scalar);
          point = p;
          fake = f;
        }
        return normalizeZ(_Point, [point, fake])[0];
      }
      /**
       * Non-constant-time multiplication. Uses double-and-add algorithm.
       * It's faster, but should only be used when you don't care about
       * an exposed secret key e.g. sig verification, which works over *public* keys.
       */
      multiplyUnsafe(scalar) {
        const { endo: endo2 } = extraOpts;
        const p = this;
        const sc = scalar;
        if (!Fn.isValid(sc))
          throw new RangeError("invalid scalar: out of range");
        if (sc === _0n4 || p.is0())
          return _Point.ZERO;
        if (sc === _1n4)
          return p;
        if (wnaf.hasCache(this))
          return this.multiply(sc);
        if (endo2) {
          const { k1neg, k1, k2neg, k2 } = splitEndoScalarN(sc);
          const { p1, p2 } = mulEndoUnsafe(_Point, p, k1, k2);
          return finishEndo(endo2.beta, p1, p2, k1neg, k2neg);
        } else {
          return wnaf.unsafe(p, sc);
        }
      }
      /**
       * Converts Projective point to affine (x, y) coordinates.
       * (X, Y, Z) ∋ (x=X/Z, y=Y/Z).
       * @param invertedZ - Z^-1 (inverted zero) - optional, precomputation is useful for invertBatch
       */
      toAffine(invertedZ) {
        const p = this;
        let iz = invertedZ;
        const { X, Y, Z } = p;
        if (Fp.eql(Z, Fp.ONE))
          return { x: X, y: Y };
        const is0 = p.is0();
        if (iz == null)
          iz = is0 ? Fp.ONE : Fp.inv(Z);
        const x = Fp.mul(X, iz);
        const y = Fp.mul(Y, iz);
        const zz = Fp.mul(Z, iz);
        if (is0)
          return { x: Fp.ZERO, y: Fp.ZERO };
        if (!Fp.eql(zz, Fp.ONE))
          throw new Error("invZ was invalid");
        return { x, y };
      }
      /**
       * Checks whether Point is free of torsion elements (is in prime subgroup).
       * Always torsion-free for cofactor=1 curves.
       */
      isTorsionFree() {
        const { isTorsionFree } = extraOpts;
        if (cofactor === _1n4)
          return true;
        if (isTorsionFree)
          return isTorsionFree(_Point, this);
        return wnaf.unsafe(this, CURVE_ORDER).is0();
      }
      clearCofactor() {
        const { clearCofactor } = extraOpts;
        if (cofactor === _1n4)
          return this;
        if (clearCofactor)
          return clearCofactor(_Point, this);
        return this.multiplyUnsafe(cofactor);
      }
      isSmallOrder() {
        if (cofactor === _1n4)
          return this.is0();
        return this.clearCofactor().is0();
      }
      toBytes(isCompressed = true) {
        abool(isCompressed, "isCompressed");
        this.assertValidity();
        return encodePoint(_Point, this, isCompressed);
      }
      toHex(isCompressed = true) {
        return bytesToHex2(this.toBytes(isCompressed));
      }
      toString() {
        return `<Point ${this.is0() ? "ZERO" : this.toHex()}>`;
      }
    };
    // base / generator point
    __publicField(_Point, "BASE", new _Point(CURVE.Gx, CURVE.Gy, Fp.ONE));
    // zero / infinity / identity point
    __publicField(_Point, "ZERO", new _Point(Fp.ZERO, Fp.ONE, Fp.ZERO));
    // 0, 1, 0
    // math field
    __publicField(_Point, "Fp", Fp);
    // scalar field
    __publicField(_Point, "Fn", Fn);
    let Point = _Point;
    const bits = Fn.BITS;
    const wnaf = new wNAF(Point, extraOpts.endo ? Math.ceil(bits / 2) : bits);
    if (bits >= 8)
      Point.BASE.precompute(8);
    Object.freeze(Point.prototype);
    Object.freeze(Point);
    return Point;
  }
  function pprefix(hasEvenY) {
    return Uint8Array.of(hasEvenY ? 2 : 3);
  }
  function getWLengths(Fp, Fn) {
    return {
      secretKey: Fn.BYTES,
      publicKey: 1 + Fp.BYTES,
      publicKeyUncompressed: 1 + 2 * Fp.BYTES,
      publicKeyHasPrefix: true,
      // Raw compact `(r || s)` signature width; DER and recovered signatures use
      // different lengths outside this helper.
      signature: 2 * Fn.BYTES
    };
  }
  function ecdh(Point, ecdhOpts = {}) {
    const { Fn } = Point;
    const randomBytes_ = ecdhOpts.randomBytes === void 0 ? randomBytes2 : ecdhOpts.randomBytes;
    const lengths = Object.assign(getWLengths(Point.Fp, Fn), {
      seed: Math.max(getMinHashLength(Fn.ORDER), 16)
    });
    function isValidSecretKey(secretKey) {
      try {
        const num = Fn.fromBytes(secretKey);
        return Fn.isValidNot0(num);
      } catch (error) {
        return false;
      }
    }
    function isValidPublicKey(publicKey, isCompressed) {
      const { publicKey: comp, publicKeyUncompressed } = lengths;
      try {
        const l = publicKey.length;
        if (isCompressed === true && l !== comp)
          return false;
        if (isCompressed === false && l !== publicKeyUncompressed)
          return false;
        return !!Point.fromBytes(publicKey);
      } catch (error) {
        return false;
      }
    }
    function randomSecretKey(seed) {
      seed = seed === void 0 ? randomBytes_(lengths.seed) : seed;
      return mapHashToField(abytes2(seed, lengths.seed, "seed"), Fn.ORDER);
    }
    function getPublicKey(secretKey, isCompressed = true) {
      return Point.BASE.multiply(Fn.fromBytes(secretKey)).toBytes(isCompressed);
    }
    function isProbPub(item) {
      const { secretKey, publicKey, publicKeyUncompressed } = lengths;
      const allowedLengths = Fn._lengths;
      if (!isBytes3(item))
        return void 0;
      const l = abytes2(item, void 0, "key").length;
      const isPub = l === publicKey || l === publicKeyUncompressed;
      const isSec = l === secretKey || !!allowedLengths?.includes(l);
      if (isPub && isSec)
        return void 0;
      return isPub;
    }
    function getSharedSecret(secretKeyA, publicKeyB, isCompressed = true) {
      if (isProbPub(secretKeyA) === true)
        throw new Error("first arg must be private key");
      if (isProbPub(publicKeyB) === false)
        throw new Error("second arg must be public key");
      const s = Fn.fromBytes(secretKeyA);
      const b = Point.fromBytes(publicKeyB);
      return b.multiply(s).toBytes(isCompressed);
    }
    const utils = {
      isValidSecretKey,
      isValidPublicKey,
      randomSecretKey
    };
    const keygen = createKeygen(randomSecretKey, getPublicKey);
    Object.freeze(utils);
    Object.freeze(lengths);
    return Object.freeze({ getPublicKey, getSharedSecret, keygen, Point, utils, lengths });
  }
  function ecdsa(Point, hash, ecdsaOpts = {}) {
    const hash_ = hash;
    ahash(hash_);
    validateObject(ecdsaOpts, {}, {
      hmac: "function",
      lowS: "boolean",
      randomBytes: "function",
      bits2int: "function",
      bits2int_modN: "function"
    });
    ecdsaOpts = Object.assign({}, ecdsaOpts);
    const randomBytes3 = ecdsaOpts.randomBytes === void 0 ? randomBytes2 : ecdsaOpts.randomBytes;
    const hmac2 = ecdsaOpts.hmac === void 0 ? (key, msg) => hmac(hash_, key, msg) : ecdsaOpts.hmac;
    const { Fp, Fn } = Point;
    const { ORDER: CURVE_ORDER, BITS: fnBits } = Fn;
    const { keygen, getPublicKey, getSharedSecret, utils, lengths } = ecdh(Point, ecdsaOpts);
    const defaultSigOpts = {
      prehash: true,
      lowS: typeof ecdsaOpts.lowS === "boolean" ? ecdsaOpts.lowS : true,
      format: "compact",
      extraEntropy: false
    };
    const hasLargeRecoveryLifts = CURVE_ORDER * _2n2 + _1n4 < Fp.ORDER;
    function isBiggerThanHalfOrder(number) {
      const HALF = CURVE_ORDER >> _1n4;
      return number > HALF;
    }
    function validateRS(title, num) {
      if (!Fn.isValidNot0(num))
        throw new Error(`invalid signature ${title}: out of range 1..Point.Fn.ORDER`);
      return num;
    }
    function assertRecoverableCurve() {
      if (hasLargeRecoveryLifts)
        throw new Error('"recovered" sig type is not supported for cofactor >2 curves');
    }
    function validateSigLength(bytes, format) {
      validateSigFormat(format);
      const size = lengths.signature;
      const sizer = format === "compact" ? size : format === "recovered" ? size + 1 : void 0;
      return abytes2(bytes, sizer);
    }
    class Signature {
      constructor(r, s, recovery) {
        __publicField(this, "r");
        __publicField(this, "s");
        __publicField(this, "recovery");
        this.r = validateRS("r", r);
        this.s = validateRS("s", s);
        if (recovery != null) {
          assertRecoverableCurve();
          if (![0, 1, 2, 3].includes(recovery))
            throw new Error("invalid recovery id");
          this.recovery = recovery;
        }
        Object.freeze(this);
      }
      static fromBytes(bytes, format = defaultSigOpts.format) {
        validateSigLength(bytes, format);
        let recid;
        if (format === "der") {
          const { r: r2, s: s2 } = DER.toSig(abytes2(bytes));
          return new Signature(r2, s2);
        }
        if (format === "recovered") {
          recid = bytes[0];
          format = "compact";
          bytes = bytes.subarray(1);
        }
        const L = lengths.signature / 2;
        const r = bytes.subarray(0, L);
        const s = bytes.subarray(L, L * 2);
        return new Signature(Fn.fromBytes(r), Fn.fromBytes(s), recid);
      }
      static fromHex(hex, format) {
        return this.fromBytes(hexToBytes2(hex), format);
      }
      assertRecovery() {
        const { recovery } = this;
        if (recovery == null)
          throw new Error("invalid recovery id: must be present");
        return recovery;
      }
      addRecoveryBit(recovery) {
        return new Signature(this.r, this.s, recovery);
      }
      // Unlike the top-level helper below, this method expects a digest that has
      // already been hashed to the curve's message representative.
      recoverPublicKey(messageHash) {
        const { r, s } = this;
        const recovery = this.assertRecovery();
        const radj = recovery === 2 || recovery === 3 ? r + CURVE_ORDER : r;
        if (!Fp.isValid(radj))
          throw new Error("invalid recovery id: sig.r+curve.n != R.x");
        const x = Fp.toBytes(radj);
        const R = Point.fromBytes(concatBytes2(pprefix((recovery & 1) === 0), x));
        const ir = Fn.inv(radj);
        const h = bits2int_modN(abytes2(messageHash, void 0, "msgHash"));
        const u1 = Fn.create(-h * ir);
        const u2 = Fn.create(s * ir);
        const Q = Point.BASE.multiplyUnsafe(u1).add(R.multiplyUnsafe(u2));
        if (Q.is0())
          throw new Error("invalid recovery: point at infinify");
        Q.assertValidity();
        return Q;
      }
      // Signatures should be low-s, to prevent malleability.
      hasHighS() {
        return isBiggerThanHalfOrder(this.s);
      }
      toBytes(format = defaultSigOpts.format) {
        validateSigFormat(format);
        if (format === "der")
          return hexToBytes2(DER.hexFromSig(this));
        const { r, s } = this;
        const rb = Fn.toBytes(r);
        const sb = Fn.toBytes(s);
        if (format === "recovered") {
          assertRecoverableCurve();
          return concatBytes2(Uint8Array.of(this.assertRecovery()), rb, sb);
        }
        return concatBytes2(rb, sb);
      }
      toHex(format) {
        return bytesToHex2(this.toBytes(format));
      }
    }
    Object.freeze(Signature.prototype);
    Object.freeze(Signature);
    const bits2int = ecdsaOpts.bits2int === void 0 ? function bits2int_def(bytes) {
      if (bytes.length > 8192)
        throw new Error("input is too large");
      const num = bytesToNumberBE(bytes);
      const delta = bytes.length * 8 - fnBits;
      return delta > 0 ? num >> BigInt(delta) : num;
    } : ecdsaOpts.bits2int;
    const bits2int_modN = ecdsaOpts.bits2int_modN === void 0 ? function bits2int_modN_def(bytes) {
      return Fn.create(bits2int(bytes));
    } : ecdsaOpts.bits2int_modN;
    const ORDER_MASK = bitMask(fnBits);
    function int2octets(num) {
      aInRange("num < 2^" + fnBits, num, _0n4, ORDER_MASK);
      return Fn.toBytes(num);
    }
    function validateMsgAndHash(message, prehash) {
      abytes2(message, void 0, "message");
      return prehash ? abytes2(hash_(message), void 0, "prehashed message") : message;
    }
    function prepSig(message, secretKey, opts) {
      const { lowS, prehash, extraEntropy } = validateSigOpts(opts, defaultSigOpts);
      message = validateMsgAndHash(message, prehash);
      const h1int = bits2int_modN(message);
      const d = Fn.fromBytes(secretKey);
      if (!Fn.isValidNot0(d))
        throw new Error("invalid private key");
      const seedArgs = [int2octets(d), int2octets(h1int)];
      if (extraEntropy != null && extraEntropy !== false) {
        const e = extraEntropy === true ? randomBytes3(lengths.secretKey) : extraEntropy;
        seedArgs.push(abytes2(e, void 0, "extraEntropy"));
      }
      const seed = concatBytes2(...seedArgs);
      const m = h1int;
      function k2sig(kBytes) {
        const k = bits2int(kBytes);
        if (!Fn.isValidNot0(k))
          return;
        const ik = Fn.inv(k);
        const q = Point.BASE.multiply(k).toAffine();
        const r = Fn.create(q.x);
        if (r === _0n4)
          return;
        const s = Fn.create(ik * Fn.create(m + r * d));
        if (s === _0n4)
          return;
        let recovery = (q.x === r ? 0 : 2) | Number(q.y & _1n4);
        let normS = s;
        if (lowS && isBiggerThanHalfOrder(s)) {
          normS = Fn.neg(s);
          recovery ^= 1;
        }
        return new Signature(r, normS, hasLargeRecoveryLifts ? void 0 : recovery);
      }
      return { seed, k2sig };
    }
    function sign(message, secretKey, opts = {}) {
      const { seed, k2sig } = prepSig(message, secretKey, opts);
      const drbg = createHmacDrbg(hash_.outputLen, Fn.BYTES, hmac2);
      const sig = drbg(seed, k2sig);
      return sig.toBytes(opts.format);
    }
    function verify(signature, message, publicKey, opts = {}) {
      const { lowS, prehash, format } = validateSigOpts(opts, defaultSigOpts);
      publicKey = abytes2(publicKey, void 0, "publicKey");
      message = validateMsgAndHash(message, prehash);
      if (!isBytes3(signature)) {
        const end = signature instanceof Signature ? ", use sig.toBytes()" : "";
        throw new Error("verify expects Uint8Array signature" + end);
      }
      validateSigLength(signature, format);
      try {
        const sig = Signature.fromBytes(signature, format);
        const P = Point.fromBytes(publicKey);
        if (lowS && sig.hasHighS())
          return false;
        const { r, s } = sig;
        const h = bits2int_modN(message);
        const is = Fn.inv(s);
        const u1 = Fn.create(h * is);
        const u2 = Fn.create(r * is);
        const R = Point.BASE.multiplyUnsafe(u1).add(P.multiplyUnsafe(u2));
        if (R.is0())
          return false;
        const v = Fn.create(R.x);
        return v === r;
      } catch (e) {
        return false;
      }
    }
    function recoverPublicKey(signature, message, opts = {}) {
      const { prehash } = validateSigOpts(opts, defaultSigOpts);
      message = validateMsgAndHash(message, prehash);
      return Signature.fromBytes(signature, "recovered").recoverPublicKey(message).toBytes();
    }
    return Object.freeze({
      keygen,
      getPublicKey,
      getSharedSecret,
      utils,
      lengths,
      Point,
      sign,
      verify,
      recoverPublicKey,
      Signature,
      hash: hash_
    });
  }

  // node_modules/@noble/curves/nist.js
  var p256_CURVE = /* @__PURE__ */ (() => ({
    p: BigInt("0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff"),
    n: BigInt("0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551"),
    h: BigInt(1),
    a: BigInt("0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc"),
    b: BigInt("0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b"),
    Gx: BigInt("0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"),
    Gy: BigInt("0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5")
  }))();
  var p256_Point = /* @__PURE__ */ weierstrass(p256_CURVE);
  var p256 = /* @__PURE__ */ ecdsa(p256_Point, sha256);

  // node_modules/@mysten/sui/dist/keypairs/passkey/publickey.mjs
  var PASSKEY_PUBLIC_KEY_SIZE = 33;
  var PASSKEY_SIGNATURE_SIZE = 64;
  var SECP256R1_SPKI_HEADER = new Uint8Array([
    48,
    89,
    48,
    19,
    6,
    7,
    42,
    134,
    72,
    206,
    61,
    2,
    1,
    6,
    8,
    42,
    134,
    72,
    206,
    61,
    3,
    1,
    7,
    3,
    66,
    0
  ]);
  var _a3;
  var PasskeyPublicKey = (_a3 = class extends PublicKey2 {
    /**
    * Create a new PasskeyPublicKey object
    * @param value passkey public key as buffer or base-64 encoded string
    */
    constructor(value) {
      super();
      if (typeof value === "string") this.data = fromBase64(value);
      else if (value instanceof Uint8Array) this.data = value;
      else this.data = Uint8Array.from(value);
      if (this.data.length !== PASSKEY_PUBLIC_KEY_SIZE) throw new Error(`Invalid public key input. Expected ${PASSKEY_PUBLIC_KEY_SIZE} bytes, got ${this.data.length}`);
    }
    /**
    * Checks if two passkey public keys are equal
    */
    equals(publicKey) {
      return super.equals(publicKey);
    }
    /**
    * Return the byte array representation of the Secp256r1 public key
    */
    toRawBytes() {
      return this.data;
    }
    /**
    * Return the Sui address associated with this Secp256r1 public key
    */
    flag() {
      return SIGNATURE_SCHEME_TO_FLAG["Passkey"];
    }
    /**
    * Verifies that the signature is valid for for the provided message
    */
    async verify(message, signature) {
      const parsed = parseSerializedPasskeySignature(signature);
      const clientDataJSON = JSON.parse(parsed.clientDataJson);
      if (clientDataJSON.type !== "webauthn.get") return false;
      if (!bytesEqual(message, fromBase64(clientDataJSON.challenge.replace(/-/g, "+").replace(/_/g, "/")))) return false;
      const pk = parsed.userSignature.slice(1 + PASSKEY_SIGNATURE_SIZE);
      if (!bytesEqual(this.toRawBytes(), pk)) return false;
      const payload = new Uint8Array([...parsed.authenticatorData, ...sha256(new TextEncoder().encode(parsed.clientDataJson))]);
      const sig = parsed.userSignature.slice(1, PASSKEY_SIGNATURE_SIZE + 1);
      return p256.verify(sig, payload, pk);
    }
  }, _a3.SIZE = PASSKEY_PUBLIC_KEY_SIZE, _a3);
  function parseSerializedPasskeySignature(signature) {
    const bytes = typeof signature === "string" ? fromBase64(signature) : signature;
    if (bytes[0] !== SIGNATURE_SCHEME_TO_FLAG.Passkey) throw new Error("Invalid signature scheme");
    const dec = PasskeyAuthenticator.parse(bytes.slice(1));
    return {
      signatureScheme: "Passkey",
      serializedSignature: toBase64(bytes),
      signature: bytes,
      authenticatorData: dec.authenticatorData,
      clientDataJson: dec.clientDataJson,
      userSignature: new Uint8Array(dec.userSignature),
      publicKey: new Uint8Array(dec.userSignature.slice(1 + PASSKEY_SIGNATURE_SIZE))
    };
  }

  // node_modules/@mysten/sui/dist/zklogin/utils.mjs
  function findFirstNonZeroIndex(bytes) {
    for (let i = 0; i < bytes.length; i++) if (bytes[i] !== 0) return i;
    return -1;
  }
  function toPaddedBigEndianBytes(num, width) {
    return hexToBytes(num.toString(16).padStart(width * 2, "0").slice(-width * 2));
  }
  function toBigEndianBytes(num, width) {
    const bytes = toPaddedBigEndianBytes(num, width);
    const firstNonZeroIndex = findFirstNonZeroIndex(bytes);
    if (firstNonZeroIndex === -1) return new Uint8Array([0]);
    return bytes.slice(firstNonZeroIndex);
  }
  function normalizeZkLoginIssuer(iss) {
    if (iss === "accounts.google.com") return "https://accounts.google.com";
    return iss;
  }

  // node_modules/@mysten/sui/dist/zklogin/jwt-utils.mjs
  function base64UrlCharTo6Bits(base64UrlChar) {
    if (base64UrlChar.length !== 1) throw new Error("Invalid base64Url character: " + base64UrlChar);
    const index = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".indexOf(base64UrlChar);
    if (index === -1) throw new Error("Invalid base64Url character: " + base64UrlChar);
    const binaryString = index.toString(2).padStart(6, "0");
    return Array.from(binaryString).map(Number);
  }
  function base64UrlStringToBitVector(base64UrlString) {
    let bitVector = [];
    for (let i = 0; i < base64UrlString.length; i++) {
      const bits = base64UrlCharTo6Bits(base64UrlString.charAt(i));
      bitVector = bitVector.concat(bits);
    }
    return bitVector;
  }
  function decodeBase64URL(s, i) {
    if (s.length < 2) throw new Error(`Input (s = ${s}) is not tightly packed because s.length < 2`);
    let bits = base64UrlStringToBitVector(s);
    const firstCharOffset = i % 4;
    if (firstCharOffset === 0) {
    } else if (firstCharOffset === 1) bits = bits.slice(2);
    else if (firstCharOffset === 2) bits = bits.slice(4);
    else throw new Error(`Input (s = ${s}) is not tightly packed because i%4 = 3 (i = ${i}))`);
    const lastCharOffset = (i + s.length - 1) % 4;
    if (lastCharOffset === 3) {
    } else if (lastCharOffset === 2) bits = bits.slice(0, bits.length - 2);
    else if (lastCharOffset === 1) bits = bits.slice(0, bits.length - 4);
    else throw new Error(`Input (s = ${s}) is not tightly packed because (i + s.length - 1)%4 = 0 (i = ${i}))`);
    if (bits.length % 8 !== 0) throw new Error(`We should never reach here...`);
    const bytes = new Uint8Array(Math.floor(bits.length / 8));
    let currentByteIndex = 0;
    for (let i$1 = 0; i$1 < bits.length; i$1 += 8) {
      const bitChunk = bits.slice(i$1, i$1 + 8);
      const byte = parseInt(bitChunk.join(""), 2);
      bytes[currentByteIndex++] = byte;
    }
    return new TextDecoder().decode(bytes);
  }
  function verifyExtendedClaim(claim) {
    if (!(claim.slice(-1) === "}" || claim.slice(-1) === ",")) throw new Error("Invalid claim");
    const json = JSON.parse("{" + claim.slice(0, -1) + "}");
    if (Object.keys(json).length !== 1) throw new Error("Invalid claim");
    const key = Object.keys(json)[0];
    return [key, json[key]];
  }
  function extractClaimValue(claim, claimName) {
    const [name, value] = verifyExtendedClaim(decodeBase64URL(claim.value, claim.indexMod4));
    if (name !== claimName) throw new Error(`Invalid field name: found ${name} expected ${claimName}`);
    return value;
  }

  // node_modules/@mysten/sui/dist/zklogin/bcs.mjs
  var zkLoginSignature = bcs.struct("ZkLoginSignature", {
    inputs: bcs.struct("ZkLoginSignatureInputs", {
      proofPoints: bcs.struct("ZkLoginSignatureInputsProofPoints", {
        a: bcs.vector(bcs.string()),
        b: bcs.vector(bcs.vector(bcs.string())),
        c: bcs.vector(bcs.string())
      }),
      issBase64Details: bcs.struct("ZkLoginSignatureInputsClaim", {
        value: bcs.string(),
        indexMod4: bcs.u8()
      }),
      headerBase64: bcs.string(),
      addressSeed: bcs.string()
    }),
    maxEpoch: bcs.u64(),
    userSignature: bcs.byteVector()
  });

  // node_modules/@mysten/sui/dist/zklogin/signature.mjs
  function parseZkLoginSignature(signature) {
    return zkLoginSignature.parse(typeof signature === "string" ? fromBase64(signature) : signature);
  }

  // node_modules/@mysten/sui/dist/zklogin/publickey.mjs
  var _data, _client, _legacyAddress, _ZkLoginPublicIdentifier_instances, toLegacyAddress_fn, _a4;
  var ZkLoginPublicIdentifier = (_a4 = class extends PublicKey2 {
    /**
    * Create a new ZkLoginPublicIdentifier object
    * @param value zkLogin public identifier as buffer or base-64 encoded string
    */
    constructor(value, { client } = {}) {
      super();
      __privateAdd(this, _ZkLoginPublicIdentifier_instances);
      __privateAdd(this, _data);
      __privateAdd(this, _client);
      __privateAdd(this, _legacyAddress);
      __privateSet(this, _client, client);
      if (typeof value === "string") __privateSet(this, _data, fromBase64(value));
      else if (value instanceof Uint8Array) __privateSet(this, _data, value);
      else __privateSet(this, _data, Uint8Array.from(value));
      __privateSet(this, _legacyAddress, __privateGet(this, _data).length !== __privateGet(this, _data)[0] + 1 + 32);
      if (__privateGet(this, _legacyAddress)) __privateSet(this, _data, normalizeZkLoginPublicKeyBytes(__privateGet(this, _data), false));
    }
    /**
    * Whether this identifier resolves to the deprecated legacy address derivation.
    */
    get legacyAddress() {
      return __privateGet(this, _legacyAddress);
    }
    static fromBytes(bytes, { client, address, legacyAddress } = {}) {
      let publicKey;
      if (legacyAddress === true) publicKey = new _a4(normalizeZkLoginPublicKeyBytes(bytes, true), { client });
      else if (legacyAddress === false) publicKey = new _a4(normalizeZkLoginPublicKeyBytes(bytes, false), { client });
      else if (address) {
        publicKey = new _a4(normalizeZkLoginPublicKeyBytes(bytes, false), { client });
        if (publicKey.toSuiAddress() !== address) publicKey = new _a4(normalizeZkLoginPublicKeyBytes(bytes, true), { client });
      } else publicKey = new _a4(bytes, { client });
      if (address && publicKey.toSuiAddress() !== address) throw new Error("Public key bytes do not match the provided address");
      return publicKey;
    }
    static fromProof(address, proof) {
      const { issBase64Details, addressSeed } = proof;
      const iss = extractClaimValue(issBase64Details, "iss");
      const legacyPublicKey = toZkLoginPublicIdentifier(BigInt(addressSeed), iss, { legacyAddress: true });
      if (legacyPublicKey.toSuiAddress() === address) return legacyPublicKey;
      const publicKey = toZkLoginPublicIdentifier(BigInt(addressSeed), iss, { legacyAddress: false });
      if (publicKey.toSuiAddress() !== address) throw new Error("Proof does not match address");
      return publicKey;
    }
    /**
    * Checks if two zkLogin public identifiers are equal
    */
    equals(publicKey) {
      return super.equals(publicKey);
    }
    toSuiAddress() {
      if (__privateGet(this, _legacyAddress)) return __privateMethod(this, _ZkLoginPublicIdentifier_instances, toLegacyAddress_fn).call(this);
      return super.toSuiAddress();
    }
    /**
    * Return the byte array representation of the zkLogin public identifier
    */
    toRawBytes() {
      return __privateGet(this, _data);
    }
    /**
    * Return the Sui address associated with this ZkLogin public identifier
    */
    flag() {
      return SIGNATURE_SCHEME_TO_FLAG["ZkLogin"];
    }
    /**
    * Verifies that the signature is valid for for the provided message
    */
    async verify(_message, _signature) {
      throw Error("does not support");
    }
    /**
    * Verifies that the signature is valid for for the provided PersonalMessage
    */
    verifyPersonalMessage(message, signature) {
      const parsedSignature = parseSerializedZkLoginSignature(signature);
      return graphqlVerifyZkLoginSignature({
        address: new _a4(parsedSignature.publicKey).toSuiAddress(),
        bytes: toBase64(message),
        signature: parsedSignature.serializedSignature,
        intentScope: "PersonalMessage",
        client: __privateGet(this, _client)
      });
    }
    /**
    * Verifies that the signature is valid for for the provided Transaction
    */
    verifyTransaction(transaction, signature) {
      const parsedSignature = parseSerializedZkLoginSignature(signature);
      return graphqlVerifyZkLoginSignature({
        address: new _a4(parsedSignature.publicKey).toSuiAddress(),
        bytes: toBase64(transaction),
        signature: parsedSignature.serializedSignature,
        intentScope: "TransactionData",
        client: __privateGet(this, _client)
      });
    }
    /**
    * Verifies that the public key is associated with the provided address
    */
    verifyAddress(address) {
      return address === super.toSuiAddress() || address === __privateMethod(this, _ZkLoginPublicIdentifier_instances, toLegacyAddress_fn).call(this);
    }
  }, _data = new WeakMap(), _client = new WeakMap(), _legacyAddress = new WeakMap(), _ZkLoginPublicIdentifier_instances = new WeakSet(), toLegacyAddress_fn = function() {
    const legacyBytes = normalizeZkLoginPublicKeyBytes(__privateGet(this, _data), true);
    const addressBytes = new Uint8Array(legacyBytes.length + 1);
    addressBytes[0] = this.flag();
    addressBytes.set(legacyBytes, 1);
    return normalizeSuiAddress(bytesToHex(blake2b(addressBytes, { dkLen: 32 })).slice(0, SUI_ADDRESS_LENGTH * 2));
  }, _a4);
  function toZkLoginPublicIdentifier(addressSeed, iss, options) {
    if (options.legacyAddress === void 0) throw new Error("legacyAddress parameter must be specified");
    const addressSeedBytesBigEndian = options.legacyAddress ? toBigEndianBytes(addressSeed, 32) : toPaddedBigEndianBytes(addressSeed, 32);
    const issBytes = new TextEncoder().encode(normalizeZkLoginIssuer(iss));
    const tmp = new Uint8Array(1 + issBytes.length + addressSeedBytesBigEndian.length);
    tmp.set([issBytes.length], 0);
    tmp.set(issBytes, 1);
    tmp.set(addressSeedBytesBigEndian, 1 + issBytes.length);
    return new ZkLoginPublicIdentifier(tmp, options);
  }
  function normalizeZkLoginPublicKeyBytes(bytes, legacyAddress) {
    const issByteLength = bytes[0] + 1;
    const addressSeed = BigInt(`0x${toHex(bytes.slice(issByteLength))}`);
    const seedBytes = legacyAddress ? toBigEndianBytes(addressSeed, 32) : toPaddedBigEndianBytes(addressSeed, 32);
    const data = new Uint8Array(issByteLength + seedBytes.length);
    data.set(bytes.slice(0, issByteLength), 0);
    data.set(seedBytes, issByteLength);
    return data;
  }
  async function graphqlVerifyZkLoginSignature({ address, bytes, signature, intentScope, client }) {
    if (!client) throw new Error("A Sui Client (GRPC, GraphQL, or JSON RPC) is required to verify zkLogin signatures");
    const resp = await client.core.verifyZkLoginSignature({
      bytes,
      signature,
      intentScope,
      address
    });
    return resp.success === true && resp.errors.length === 0;
  }
  function parseSerializedZkLoginSignature(signature) {
    const bytes = typeof signature === "string" ? fromBase64(signature) : signature;
    if (bytes[0] !== SIGNATURE_SCHEME_TO_FLAG.ZkLogin) throw new Error("Invalid signature scheme");
    const { inputs, maxEpoch, userSignature } = parseZkLoginSignature(bytes.slice(1));
    const { issBase64Details, addressSeed } = inputs;
    const iss = extractClaimValue(issBase64Details, "iss");
    const publicIdentifier = toZkLoginPublicIdentifier(BigInt(addressSeed), iss, { legacyAddress: false });
    return {
      serializedSignature: toBase64(bytes),
      signatureScheme: "ZkLogin",
      zkLogin: {
        inputs,
        maxEpoch,
        userSignature,
        iss,
        addressSeed: BigInt(addressSeed)
      },
      signature: bytes,
      publicKey: publicIdentifier.toRawBytes()
    };
  }

  // node_modules/@mysten/sui/dist/cryptography/signature.mjs
  function toSerializedSignature({ signature, signatureScheme, publicKey }) {
    if (!publicKey) throw new Error("`publicKey` is required");
    const pubKeyBytes = publicKey.toRawBytes();
    const serializedSignature = new Uint8Array(1 + signature.length + pubKeyBytes.length);
    serializedSignature.set([SIGNATURE_SCHEME_TO_FLAG[signatureScheme]]);
    serializedSignature.set(signature, 1);
    serializedSignature.set(pubKeyBytes, 1 + signature.length);
    return toBase64(serializedSignature);
  }
  function parseSerializedSignature(serializedSignature) {
    const bytes = fromBase64(serializedSignature);
    const signatureScheme = SIGNATURE_FLAG_TO_SCHEME[bytes[0]];
    switch (signatureScheme) {
      case "Passkey":
        return parseSerializedPasskeySignature(serializedSignature);
      case "MultiSig":
        return {
          serializedSignature,
          signatureScheme,
          multisig: suiBcs.MultiSig.parse(bytes.slice(1)),
          bytes,
          signature: void 0
        };
      case "ZkLogin":
        return parseSerializedZkLoginSignature(serializedSignature);
      case "ED25519":
      case "Secp256k1":
      case "Secp256r1":
        return parseSerializedKeypairSignature(serializedSignature);
      default:
        throw new Error("Unsupported signature scheme");
    }
  }

  // node_modules/@mysten/sui/dist/cryptography/keypair.mjs
  var Signer = class {
    /**
    * Sign messages with a specific intent. By combining the message bytes with the intent before hashing and signing,
    * it ensures that a signed message is tied to a specific purpose and domain separator is provided
    */
    async signWithIntent(bytes, intent) {
      const digest = blake2b(messageWithIntent(intent, bytes), { dkLen: 32 });
      return {
        signature: toSerializedSignature({
          signature: await this.sign(digest),
          signatureScheme: this.getKeyScheme(),
          publicKey: this.getPublicKey()
        }),
        bytes: toBase64(bytes)
      };
    }
    /**
    * Signs provided transaction by calling `signWithIntent()` with a `TransactionData` provided as intent scope
    */
    async signTransaction(bytes) {
      return this.signWithIntent(bytes, "TransactionData");
    }
    /**
    * Signs provided personal message by calling `signWithIntent()` with a `PersonalMessage` provided as intent scope
    */
    async signPersonalMessage(bytes) {
      const { signature } = await this.signWithIntent(bcs.byteVector().serialize(bytes).toBytes(), "PersonalMessage");
      return {
        bytes: toBase64(bytes),
        signature
      };
    }
    async signAndExecuteTransaction({ transaction, client }) {
      transaction.setSenderIfNotSet(this.toSuiAddress());
      const bytes = await transaction.build({ client });
      const { signature } = await this.signTransaction(bytes);
      return client.core.executeTransaction({
        transaction: bytes,
        signatures: [signature],
        include: {
          transaction: true,
          effects: true
        }
      });
    }
    toSuiAddress() {
      return this.getPublicKey().toSuiAddress();
    }
  };

  // node_modules/@mysten/sui/dist/keypairs/secp256r1/publickey.mjs
  var SECP256R1_PUBLIC_KEY_SIZE = 33;
  var _a5;
  var Secp256r1PublicKey = (_a5 = class extends PublicKey2 {
    /**
    * Create a new Secp256r1PublicKey object
    * @param value secp256r1 public key as buffer or base-64 encoded string
    */
    constructor(value) {
      super();
      if (typeof value === "string") this.data = fromBase64(value);
      else if (value instanceof Uint8Array) this.data = value;
      else this.data = Uint8Array.from(value);
      if (this.data.length !== SECP256R1_PUBLIC_KEY_SIZE) throw new Error(`Invalid public key input. Expected ${SECP256R1_PUBLIC_KEY_SIZE} bytes, got ${this.data.length}`);
    }
    /**
    * Checks if two Secp256r1 public keys are equal
    */
    equals(publicKey) {
      return super.equals(publicKey);
    }
    /**
    * Return the byte array representation of the Secp256r1 public key
    */
    toRawBytes() {
      return this.data;
    }
    /**
    * Return the Sui address associated with this Secp256r1 public key
    */
    flag() {
      return SIGNATURE_SCHEME_TO_FLAG["Secp256r1"];
    }
    /**
    * Verifies that the signature is valid for for the provided message
    */
    async verify(message, signature) {
      let bytes;
      if (typeof signature === "string") {
        const parsed = parseSerializedSignature(signature);
        if (parsed.signatureScheme !== "Secp256r1") throw new Error("Invalid signature scheme");
        if (!bytesEqual(this.toRawBytes(), parsed.publicKey)) throw new Error("Signature does not match public key");
        bytes = parsed.signature;
      } else bytes = signature;
      return p256.verify(bytes, message, this.toRawBytes());
    }
  }, _a5.SIZE = SECP256R1_PUBLIC_KEY_SIZE, _a5);

  // node_modules/@mysten/webcrypto-signer/dist/index.mjs
  function getCompressedPublicKey(publicKey) {
    const rawBytes = new Uint8Array(publicKey);
    const x = rawBytes.slice(1, 33);
    const prefix = (rawBytes.slice(33, 65)[31] & 1) === 0 ? 2 : 3;
    const compressed = new Uint8Array(Secp256r1PublicKey.SIZE);
    compressed[0] = prefix;
    compressed.set(x, 1);
    return compressed;
  }
  var _publicKey, _a6;
  var WebCryptoSigner = (_a6 = class extends Signer {
    constructor(privateKey, publicKey) {
      super();
      __privateAdd(this, _publicKey);
      this.privateKey = privateKey;
      __privateSet(this, _publicKey, new Secp256r1PublicKey(publicKey));
    }
    static async generate({ extractable = false } = {}) {
      const keypair = await globalThis.crypto.subtle.generateKey({
        name: "ECDSA",
        namedCurve: "P-256"
      }, extractable, ["sign", "verify"]);
      const publicKey = await globalThis.crypto.subtle.exportKey("raw", keypair.publicKey);
      return new _a6(keypair.privateKey, getCompressedPublicKey(new Uint8Array(publicKey)));
    }
    /**
    * Imports a keypair using the value returned by `export()`.
    */
    static import(data) {
      return new _a6(data.privateKey, data.publicKey);
    }
    getKeyScheme() {
      return "Secp256r1";
    }
    /**
    * Exports the keypair so that it can be stored in IndexedDB.
    */
    export() {
      const exportedKeypair = {
        privateKey: this.privateKey,
        publicKey: __privateGet(this, _publicKey).toRawBytes()
      };
      Object.defineProperty(exportedKeypair, "toJSON", {
        enumerable: false,
        value: () => {
          throw new Error("The exported keypair must not be serialized. It must be stored in IndexedDB directly.");
        }
      });
      return exportedKeypair;
    }
    getPublicKey() {
      return __privateGet(this, _publicKey);
    }
    async sign(bytes) {
      const rawSignature = await globalThis.crypto.subtle.sign({
        name: "ECDSA",
        hash: "SHA-256"
      }, this.privateKey, bytes);
      const signature = p256.Signature.fromBytes(new Uint8Array(rawSignature));
      return (signature.hasHighS() ? new p256.Signature(signature.r, p256.Point.Fn.neg(signature.s)) : signature).toBytes("compact");
    }
  }, _publicKey = new WeakMap(), _a6);

  // node_modules/idb-keyval/dist/index.js
  function promisifyRequest(request) {
    return new Promise((resolve, reject) => {
      request.oncomplete = request.onsuccess = () => resolve(request.result);
      request.onabort = request.onerror = () => reject(request.error);
    });
  }
  function createStore(dbName, storeName) {
    let dbp;
    const getDB = () => {
      if (dbp)
        return dbp;
      const request = indexedDB.open(dbName);
      request.onupgradeneeded = () => request.result.createObjectStore(storeName);
      dbp = promisifyRequest(request);
      dbp.then((db) => {
        db.onclose = () => dbp = void 0;
      }, () => {
        dbp = void 0;
      });
      return dbp;
    };
    return (txMode, callback) => getDB().then((db) => callback(db.transaction(storeName, txMode).objectStore(storeName)));
  }
  var defaultGetStoreFunc;
  function defaultGetStore() {
    if (!defaultGetStoreFunc) {
      defaultGetStoreFunc = createStore("keyval-store", "keyval");
    }
    return defaultGetStoreFunc;
  }
  function get(key, customStore = defaultGetStore()) {
    return customStore("readonly", (store) => promisifyRequest(store.get(key)));
  }
  function set(key, value, customStore = defaultGetStore()) {
    return customStore("readwrite", (store) => {
      store.put(value, key);
      return promisifyRequest(store.transaction);
    });
  }

  // wallet-client.js
  var KEY = "tobmate-sui-wallet-v1";
  async function loadSigner() {
    const saved = await get(KEY);
    if (!saved) return null;
    return await WebCryptoSigner.import(saved);
  }
  async function createSigner() {
    const signer = await WebCryptoSigner.generate();
    await set(KEY, signer.export());
    return signer;
  }
  async function getOrCreateSigner() {
    return await loadSigner() || await createSigner();
  }
  window.TobmateWallet = {
    async create() {
      const signer = await getOrCreateSigner();
      const address = signer.toSuiAddress();
      return {
        address,
        scheme: signer.getKeyScheme()
      };
    },
    async signMessage(message) {
      const signer = await loadSigner();
      if (!signer) {
        throw new Error(
          window.TobmatePopupI18n?.message("walletNotCreated") || "Wallet not created"
        );
      }
      const bytes = new TextEncoder().encode(message);
      return await signer.signPersonalMessage(bytes);
    },
    async getAddress() {
      const signer = await loadSigner();
      return signer ? signer.toSuiAddress() : null;
    }
  };
})();
/*! Bundled license information:

@scure/base/index.js:
  (*! scure-base - MIT License (c) 2022 Paul Miller (paulmillr.com) *)

@noble/curves/utils.js:
@noble/curves/abstract/modular.js:
@noble/curves/abstract/curve.js:
@noble/curves/abstract/weierstrass.js:
@noble/curves/nist.js:
  (*! noble-curves - MIT License (c) 2022 Paul Miller (paulmillr.com) *)
*/

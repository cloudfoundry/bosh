import sys

(F_LINK,
 F_LINKABLE,
 F_OPTIONAL) = [ 1<<x for x in range(3) ]


def AddVersion(version, ns, versionId='', isLegacy=0, serviceNs=''):
  isLegacy = "true" if isLegacy else "false"
  builder = []
  builder.append("add_version(")
  ParseStrings(builder, [version, ns, versionId])
  builder.append(", %s, " % isLegacy)
  ParseString(builder, serviceNs)
  builder.append(")")
  print "".join(builder)


def AddVersionParent(version, parent):
  builder = []
  builder.append("add_version_parent(")
  ParseStrings(builder, [version, parent])
  builder.append(")")
  print "".join(builder)


def CreateManagedType(vmodlName, wsdlName, parent, version, props, methods):
  builder = []
  builder.append("create_managed_type(")
  ParseStrings(builder, [vmodlName, wsdlName, parent, version])
  builder.append(", ")
  ParseProps(builder, props)
  builder.append(", ")
  ParseMethods(builder, methods)
  builder.append(")")
  print "".join(builder)


def CreateDataType(vmodlName, wsdlName, parent, version, props):
  builder = []
  builder.append("create_data_type(")
  ParseStrings(builder, [vmodlName, wsdlName, parent, version])
  builder.append(", ")
  ParseProps(builder, props)
  builder.append(")")
  print "".join(builder)


def CreateEnumType(vmodlName, wsdlName, version, values):
  builder = []
  builder.append("create_enum_type(")
  ParseStrings(builder, [vmodlName, wsdlName, version])
  builder.append(", [")
  ParseStrings(builder, values)
  builder.append("])")
  print "".join(builder)


def ParseFlags(builder, flags):
  builder.append("{")
  flags_builder = []
  if flags & F_LINK:
    flags_builder.append(":link => true")
  if flags & F_LINKABLE:
    flags_builder.append(":linkable => true")
  if flags & F_OPTIONAL:
    flags_builder.append(":optional => true")
  builder.append(", ".join(flags_builder))
  builder.append("}")


def ParseProps(builder, props):
  if props is None:
    builder.append("nil")
  else:
    entries = []
    for p in props:
      name, typeName, propVersion, flags = p[:4]
      privId = len(p) == 5
      entry_builder = []

      entry_builder.append("[")
      ParseString(entry_builder, name)
      entry_builder.append(", ")
      ParseString(entry_builder, typeName)
      entry_builder.append(", ")
      ParseString(entry_builder, propVersion)
      entry_builder.append(", ")
      ParseFlags(entry_builder, flags)
      if privId:
        entry_builder.append(", ")
        ParseString(entry_builder, p[4])
      entry_builder.append("]")
      entries.append("".join(entry_builder))
    builder.append("[")
    builder.append(", ".join(entries))
    builder.append("]")


def ParseString(builder, string):
  if string == None:
    builder.append("nil")
  else:
    builder.append("\"%s\"" % string)


def ParseStrings(builder, strings):
  entries = []
  for string in strings:
    ParseString(entries, string)
  builder.append(", ".join(entries))

def ParseMethods(builder, methods):
  if methods is None:
    builder.append("nil")
  else:
    entries = []
    for (mVmodl, mWsdl, mVersion, mParams, mResult, mPrivilege, mFaults) in methods:
      entry_builder = []
      entry_builder.append("[")
      ParseStrings(entry_builder, [mVmodl, mWsdl, mVersion])
      entry_builder.append(", ")
      ParseProps(entry_builder, mParams)

      entry_builder.append(", [")
      resultFlags, resultName, methodResultName = mResult
      ParseFlags(entry_builder, resultFlags)
      entry_builder.append(", ")
      ParseString(entry_builder, resultName)
      entry_builder.append(", ")
      ParseString(entry_builder, methodResultName)
      entry_builder.append("], ")

      ParseString(entry_builder, mPrivilege)
      entry_builder.append(", ")

      if mFaults is None:
        entry_builder.append("nil")
      else:
        faults_builder = []
        for fault in mFaults:
          ParseString(faults_builder, fault)
        entry_builder.append("[")
        entry_builder.append(", ".join(faults_builder))
        entry_builder.append("]")

      entry_builder.append("]")
      entries.append("".join(entry_builder))
    builder.append("[")
    builder.append(", ".join(entries))
    builder.append("]")

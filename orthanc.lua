dicom_protocol = Proto("orthanc-dicom",  "Orthanc DICOM Protocol")

-- We define the fields, the names used in filters and what will be shown
pdu_type = ProtoField.int8("dicom.pdu_type", "pduType", base.DEC)
message_length = ProtoField.int16("dicom.message_length", "messageLength", base.DEC)
protocol_version = ProtoField.int8("dicom.protocol_version", "protocolVersion", base.DEC)
calling_application = ProtoField.string("dicom.calling_app", "callingApplication")
called_application = ProtoField.string("dicom.called_app", "calledApplication")
context_id = ProtoField.int8("dicom.context_id", "contextId", base.DEC)
context_size = ProtoField.int8("dicom.context_size", "contextSize", base.DEC)
context_name = ProtoField.string("dicom.context_name", "contextName")

dicom_protocol.fields = {message_length, pdu_type, protocol_version, calling_application, 
                         called_application, context_id, context_size, context_name}

function dicom_protocol.dissector(buffer, pinfo, tree)
  local req_type = ""
  local req_types = {["0100"]="ASSOC Request", ["0200"]="ASSOC Accept", ["0300"]="ASSOC Reject",
                     ["0400"]="Data", ["0500"]="RELEASE Request", ["0600"]="RELEASE Response", ["0700"]="ABORT"}
  local context_types = {["10"]="Application Context", [20]="Presentation Context", [30]="Abstract Syntax", 
                         [40]="Transfer Syntax", [50]="User Info"}

  length = buffer:len()
  if length == 0 then return end

  pinfo.cols.protocol = dicom_protocol.name

  local subtree = tree:add(dicom_protocol, buffer(), "Orthanc DICOM Protocol Data")
  subtree:add_le(pdu_type, buffer(0,2))
  subtree:add(message_length, buffer(2,4))

  req_type = tostring(buffer(0,2))
  if(not(req_types[req_type])) then
    req_type = "[Unknown PDU]"
  else
    req_type = req_types[req_type]
  end

  local assoctree = subtree:add(dicom_protocol, buffer(), req_type .. " info")
  if string.find(req_type, "ASSOC") then
    assoctree:add(protocol_version, buffer(6, 2))
    assoctree:add(calling_application, buffer(10, 16))
    assoctree:add(called_application, buffer(26, 16))
    -- Check the Assoc type
    local context_type_str = tostring(buffer(74, 1))
    if context_type_str == "10" or context_type_str == "20" then
      local subassoctree = assoctree:add(dicom_protocol, buffer(), context_types[context_type_str])
      subassoctree:add(context_name, buffer(78, 21))
    end
    assoctree:add(context_id, buffer(74,1))
    assoctree:add(context_size, buffer(76, 2))
  end

  ---
  --Exercise for the readers?
  ---
end

local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(4242, dicom_protocol)

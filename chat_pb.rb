# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: chat.proto

require 'google/protobuf'


descriptor_data = "\n\nchat.proto\x12\x04\x63hat\"A\n\x0b\x43hatMessage\x12\x0e\n\x06sender\x18\x01 \x01(\t\x12\x0f\n\x07\x63ontent\x18\x02 \x01(\t\x12\x11\n\ttimestamp\x18\x03 \x01(\t2?\n\x0b\x43hatService\x12\x30\n\x04\x43hat\x12\x11.chat.ChatMessage\x1a\x11.chat.ChatMessage(\x01\x30\x01\x62\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Chat
  ChatMessage = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("chat.ChatMessage").msgclass
end

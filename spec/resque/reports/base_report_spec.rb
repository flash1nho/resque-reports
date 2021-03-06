# coding: utf-8
require 'spec_helper'
require 'stringio'

class MyTypeReport < Resque::Reports::BaseReport
  extension :type

  def write(io, force = false)
    write_line io, build_table_header

    data_each(true) do |element|
      write_line io, build_table_row(element)
    end
  end

  def write_line(io, row)
    io << "#{row.nil? ? 'nil' : row.join('|')}\r\n"
  end
end

class MyReport < MyTypeReport
  queue :my_type_reports
  source :select_data
  encoding UTF8

  directory File.join(Dir.tmpdir, 'resque-reports')

  table do |element|
    column 'First one', :one
    column 'Second', decorate_second(element[:two])
  end

  create do |param|
    @main_param = param
  end

  def decorate_second(text)
    "#{text} - is second"
  end

  def select_data
    [{one: 'one', two: 'one'}, {one: @main_param, two: @main_param}]
  end
end

describe 'Resque::Reports::BaseReport successor' do
  let(:io) { StringIO.new }
  let(:my_report) { MyReport.new('test') }
  let(:dummy) { Resque::Reports::Extensions::Dummy.new }

  describe '#extension' do
    before { allow(File).to receive(:exists?).and_return(true) }

    it { expect(File.extname(my_report.filename)).to eq '.type' }
  end

  describe '#source' do
    before { allow(my_report).to receive(:select_data).and_return([dummy]) }

    it { expect(my_report).to receive(:select_data) }

    after { my_report.build true }
  end

  describe '#directory' do
    subject { my_report.instance_variable_get(:@cache_file) }
    let(:tmpdir) { File.join(Dir.tmpdir, 'resque-reports') }

    it { expect(subject.instance_variable_get(:@dir)).to eq tmpdir }
  end

  describe '#create' do
    it { expect(my_report.instance_variable_get(:@main_param)).to eq 'test' }
  end

  describe '#encoding' do
    subject { my_report.instance_variable_get(:@cache_file) }
    let(:utf_coding) { Resque::Reports::Extensions::Encodings::UTF8 }

    it { expect(subject.instance_variable_get(:@coding)).to eq utf_coding }
  end

  describe '#write' do
    subject { MyReport.new('#write test') }

    before do
      allow(subject).to receive(:data_each) { |&block| block.call(dummy) }
      allow(subject).to receive(:build_table_row).and_return(['row'])
      allow(subject).to receive(:build_table_header).and_return(['header'])

      subject.write(io)
    end

    it { expect(io.string).to eq "header\r\nrow\r\n" }
  end

  describe '#bg_build' do
    let(:job_class) { Resque::Reports::ReportJob }

    context 'when report is building twice' do
      subject { MyReport.new('#bg_build test') }

      before { allow(job_class).to receive(:enqueue_to).and_return('job_id') }

      it do
        expect(job_class).to receive(:enqueue_to).twice
      end

      after do
        2.times { subject.bg_build true }
      end
    end

    context 'when report is building' do
      subject { MyReport.new('#bg_build test') }

      before { allow(job_class).to receive(:enqueue_to).and_return('job_id') }

      it { expect(job_class).to receive(:enqueue_to) }

      after { subject.bg_build true }
    end

    context 'when report is not build yet' do
      subject { MyReport.new('#bg_build test') }

      before do
        allow(job_class).to receive(:enqueued?).and_return(double('Meta', meta_id: 'enqueued_job_id'))
      end

      it { expect(subject.bg_build(true)).to eq 'enqueued_job_id' }
    end
  end

  describe '#build' do
    context 'when report decorated' do
      subject { MyReport.new('#build test') }

      it { expect(subject).to receive(:decorate_second).exactly(3).times }

      after  { subject.build true }
    end
    context 'when report was built' do
      subject { MyReport.new('was built test') }

      before { subject.build true }

      it { expect(subject).to be_exists }
      it do
        expect(File.read(subject.filename))
          .to eq <<-REPORT.gsub(/^ {12}/, '')
            First one|Second\r
            one|one - is second\r
            was built test|was built test - is second\r
          REPORT
      end
    end
  end

  describe '#data_each' do
    subject { MyReport.new('#data_each test') }

    it { expect(subject).to receive(:data_each) }

    after { subject.write(io) }
  end

  describe '#build_table_header' do
    subject { MyReport.new('#build_table_header test') }

    it { expect(subject).to receive(:build_table_header) }

    after { subject.write(io) }
  end

  describe '#build_table_row' do
    subject { MyReport.new('#build_table_row test') }

    it { expect(subject).to receive(:build_table_row).twice }

    after { subject.write(io) }
  end

end

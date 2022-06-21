# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::RecordingsController, type: :controller do
  let(:user) { create(:user) }

  before do
    request.headers['ACCEPT'] = 'application/json'
    session[:user_id] = user.id
  end

  describe '#index' do
    it 'returns recordings ids that belong to current_user' do
      recordings = create_list(:recording, 6)
      create_list(:room, 5, user:, recordings:)
      get :index

      expect(response).to have_http_status(:ok)
      response_recording_ids = JSON.parse(response.body)['data'].map { |recording| recording['id'] }
      expect(response_recording_ids).to eq(recordings.pluck(:id))
    end

    it 'returns no ids when there are no recordings that belong to current_user' do
      create_list(:room, 5, user:)
      get :index

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to be_empty
    end

    it 'returns the recordings according to the query' do
      recordings = create_list(:recording, 5) do |recording|
        recording.name = "Greenlight #{rand(100 - 999)}"
      end

      create(:room, user:, recordings:)

      create_list(:recording, 10)

      get :index, params: { search: 'greenlight' }
      response_recording_ids = JSON.parse(response.body)['data'].map { |recording| recording['id'] }
      expect(response_recording_ids).to match_array(recordings.pluck(:id))
    end

    it 'returns all recordings if the search bar is empty' do
      recordings = create_list(:recording, 10)
      create(:room, user:, recordings:)

      get :index, params: { search: '' }
      response_recording_ids = JSON.parse(response.body)['data'].map { |recording| recording['id'] }
      expect(response_recording_ids).to match_array(recordings.pluck(:id))
    end
  end

  describe '#update' do
    let(:room) { create(:room, user:) }
    let(:recording) { create(:recording, room:) }

    before do
      allow_any_instance_of(BigBlueButtonApi).to receive(:update_recordings).and_return(http_ok_response)
    end

    it 'updates the recordings name with valid params returning :ok status code' do
      expect_any_instance_of(BigBlueButtonApi).to receive(:update_recordings).with(record_id: recording.record_id,
                                                                                   meta_hash: { meta_name: 'My Awesome Recording!' })

      expect { post :update, params: { recording: { name: 'My Awesome Recording!' }, id: recording.record_id } }.to(change { recording.reload.name })
      expect(response).to have_http_status(:ok)
    end

    it 'does not update the recordings name for invalid params returning a :bad_request status code' do
      expect_any_instance_of(BigBlueButtonApi).not_to receive(:update_recordings)

      expect do
        post :update,
             params: { recording: { name: '' }, id: recording.record_id }
      end.not_to(change { recording.reload.name })

      expect(response).to have_http_status(:bad_request)
    end

    it 'does not update the recordings name for invalid recording id returning :not_found status code' do
      expect_any_instance_of(BigBlueButtonApi).not_to receive(:update_recordings)
      post :update, params: { recording: { name: '' }, id: '404' }
      expect(response).to have_http_status(:not_found)
    end
  end

  # TODO: - Uncomment once delete_recordings is no longer in destroy
  # describe '#destroy' do
  #   it 'deletes recording from the database' do
  #     recording = create(:recording)
  #     expect { delete :destroy, params: { id: recording.id } }.to change(Recording, :count).by(-1)
  #   end

  #   it 'deletes formats associated with the recording from the database' do
  #     recording = create(:recording)
  #     create_list(:format, 5, recording:)
  #     expect { delete :destroy, params: { id: recording.id } }.to change(Format, :count).by(-5)
  #   end
  # end

  describe '#recordings' do
    it 'calls the RecordingsSync service correctly' do
      expect_any_instance_of(RecordingsSync).to receive(:call)
      get :resync
    end

    it 'calls the RecordingsSync service with correct params' do
      expect(RecordingsSync).to receive(:new).with(user:)
      get :resync
    end
  end

  describe '#publish_recording' do
    it 'Updates Recording with new visibility value' do
      recording = create(:recording, visibility: 'Unpublished')
      allow_any_instance_of(BigBlueButtonApi).to receive(:publish_recordings).and_return(http_ok_response)
      expect { post :publish_recording, params: { publish: 'true', record_id: recording.record_id } }.to change {
                                                                                                           recording.reload.visibility
                                                                                                         }.to('Published')
    end
  end
end

def http_ok_response
  Net::HTTPSuccess.new(1.0, '200', 'OK')
end
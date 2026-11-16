require 'cgi'
require 'pony'

module LinkedData
  module Utils
    class Notifications
      def self.new_note(note)
        note.bring_remaining
        note.creator.bring(:username) if note.creator.bring?(:username)
        note.relatedOntology.each { |o| o.bring(:name) if o.bring?(:name); o.bring(:subscriptions) if o.bring?(:subscriptions) }
        ontologies = note.relatedOntology.map { |o| o.name }.join(", ")
        # Fix the note URL when using replace_url_prefix (in another VM than NCBO)
        note_hash = note.id.to_s.split('/').last
        note_url = "http://#{LinkedData.settings.ui_host}/ontologies/#{note.relatedOntology.first.acronym}?p=notes&noteid=#{note_hash}"


        subject = "[#{LinkedData.settings.ui_name} Notes] [#{ontologies}] #{note.subject}"
        body = NEW_NOTE.gsub("%username%", note.creator.username)
                       .gsub("%ontologies%", ontologies)
                       .gsub("%note_subject%", note.subject || "")
                       .gsub("%note_body%", note.body || "")
                       .gsub("%note_url%", note_url)
                       .gsub('%ui_name%', LinkedData.settings.ui_name)

        note.relatedOntology.each do |ont|
          Notifier.notify_subscribed_separately subject, body, ont, 'NOTES'
          Notifier.notify_mails_grouped subject, body, Notifier.support_mails + Notifier.admin_mails(ont)
        end
      end

      def self.submission_processed(submission)
        submission.bring_remaining
        ontology = submission.ontology
        ontology.bring(:name, :acronym)
        ontology.bring(:summaryOnly) if ontology.bring?(:summaryOnly)
        ontology_ui = LinkedData::Hypermedia.generate_links(ontology)['ui']
        ontology_location = "#{ontology_ui}?invalidate_cache=true"

        if ontology.summaryOnly && !submission.archived?
          subject, body = metadata_only_email(submission, ontology, ontology_ui, ontology_location)
        else
          result = submission.ready? || submission.archived? ? 'Success' : 'Failure'
          status = LinkedData::Models::SubmissionStatus.readable_statuses(submission.submissionStatus)
          subject = "[#{LinkedData.settings.ui_name}] #{ontology.name} Parsing #{result}"
          body = SUBMISSION_PROCESSED.gsub('%ontology_name%', ontology.name)
                                     .gsub('%ontology_acronym%', ontology.acronym)
                                     .gsub('%statuses%', status.join('<br/>'))
                                     .gsub('%admin_email%', LinkedData.settings.email_sender)
                                     .gsub('%ontology_location%', ontology_location)
                                     .gsub('%ui_name%', LinkedData.settings.ui_name)
        end

        Notifier.notify_subscribed_separately subject, body, ontology, 'PROCESSING'
        Notifier.notify_mails_grouped subject, body, Notifier.support_mails + Notifier.admin_mails(ontology)
      end

      # A metadata-only submission has no file, so its processing can only fail: the email says that it is expected,
      # how to add the file (new version form, filled with the metadata of the latest version)
      # and how many Recommended metadata fields are still empty
      def self.metadata_only_email(submission, ontology, ontology_ui, ontology_location)
        ui_name = LinkedData.settings.ui_name
        subject = "[#{ui_name}] #{ontology.name} (#{ontology.acronym}): metadata saved, no file to process"
        body = SUBMISSION_METADATA_ONLY.gsub('%recommended%', recommended_paragraph(submission, ontology_ui))
                                       .gsub('%new_version_url%', "#{ontology_ui}/submissions/new")
                                       .gsub('%ontology_name%', ontology.name)
                                       .gsub('%ontology_acronym%', ontology.acronym)
                                       .gsub('%admin_email%', LinkedData.settings.email_sender)
                                       .gsub('%ontology_location%', ontology_location)
                                       .gsub('%ui_name%', ui_name)
        [subject, body]
      end

      # Number of empty Recommended fields with the link to the Edit page of the submission (its Recommended badges);
      # empty when no Recommended field is empty, or when the count fails (the email is then sent without it)
      def self.recommended_paragraph(submission, ontology_ui)
        count = recommended_empty_count(submission)
        return '' if count.nil? || count.zero?

        RECOMMENDED_EMPTY.gsub('%count%', count.to_s)
                         .gsub('%fields%', count == 1 ? 'field is' : 'fields are')
                         .gsub('%edit_url%', "#{ontology_ui}/submissions/#{submission.submissionId}/edit")
      end

      # Recommended metadata fields filled by the author. Copy of SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES
      # in ontoportal_web_ui (Recommended badges of the Edit page): keep both lists identical.
      # Display only, never required: only used to count the empty ones in the email
      RECOMMENDED_ATTRIBUTES = %w[
        versionIRI hasFormalityLevel hasOntologySyntax naturalLanguage isOfType
        abstract notes homepage documentation keywords hiddenLabel alternative publication
        valid
        useGuidelines copyrightHolder
        hasContributor publisher fundedBy endorsedBy translator
        isFormatOf hasFormat endpoint source
        bugDatabase audience repository mailingList toDoList award
        knownUsage designedForOntologyTask coverage example
        hasPriorVersion hasPart similarTo isAlignedTo hasDisparateModelling useImports usedBy workTranslation translationOfWork
        preferredNamespaceUri preferredNamespacePrefix metadataVoc
        usedOntologyEngineeringTool accrualMethod accrualPeriodicity accrualPolicy competencyQuestion
      ].freeze

      # nil when the count fails
      def self.recommended_empty_count(submission)
        RECOMMENDED_ATTRIBUTES.count do |attr|
          value = begin
            submission.send(attr)
          rescue StandardError
            nil
          end
          metadata_value_blank?(value)
        end
      rescue StandardError
        nil
      end

      # Same rule as SubmissionInputsHelper#metadata_value_blank? in ontoportal_web_ui
      def self.metadata_value_blank?(value)
        case value
        when nil then true
        when String then value.strip.empty?
        when Array then value.all? { |v| metadata_value_blank?(v) }
        when Hash then value.values.all? { |v| metadata_value_blank?(v) }
        else false
        end
      end

      def self.remote_ontology_pull(submission)
        submission.bring_remaining
        ontology = submission.ontology
        ontology.bring(:name, :acronym, :administeredBy)

        subject = "[#{LinkedData.settings.ui_name}] Load from URL failure for #{ontology.name}"
        body = REMOTE_PULL_FAILURE.gsub('%ont_pull_location%', submission.pullLocation.to_s)
                                  .gsub('%ont_name%', ontology.name)
                                  .gsub('%ont_acronym%', ontology.acronym)
                                  .gsub('%ontology_location%', LinkedData::Hypermedia.generate_links(ontology)['ui'])
                                  .gsub('%support_mail%', Notifier.support_mails.first || '')
                                  .gsub('%ui_name%', LinkedData.settings.ui_name)
        recipients = []
        ontology.administeredBy.each do |user|
          user.bring(:email) if user.bring?(:email)
          recipients << user.email
        end
        if !LinkedData.settings.admin_emails.nil? && LinkedData.settings.admin_emails.kind_of?(Array)
          LinkedData.settings.admin_emails.each do |admin_email|
            recipients << admin_email
          end
        end

        Notifier.notify_mails_grouped subject, body, [Notifier.admin_mails(ontology) + Notifier.support_mails]
      end

      def self.new_user(user)
        user.bring_remaining

        subject = "[#{LinkedData.settings.ui_name}] New User: #{user.username}"
        body = NEW_USER_CREATED.gsub('%username%', user.username.to_s)
                               .gsub('%email%', user.email.to_s)
                               .gsub('%site_url%', LinkedData.settings.ui_host)
                               .gsub('%ui_name%', LinkedData.settings.ui_name)

        Notifier.notify_support_grouped subject, body
      end

      def self.new_ontology(ont)
        ont.bring_remaining

        subject = "[#{LinkedData.settings.ui_name}] New Ontology: #{ont.acronym}"
        body = NEW_ONTOLOGY_CREATED.gsub('%acronym%', ont.acronym)
                                   .gsub('%name%', ont.name.to_s)
                                   .gsub('%addedby%', ont.administeredBy[0].to_s)
                                   .gsub('%site_url%', LinkedData.settings.ui_host)
                                   .gsub('%ont_url%', LinkedData::Hypermedia.generate_links(ont)['ui'])
                                   .gsub('%ui_name%', LinkedData.settings.ui_name)

        Notifier.notify_support_grouped subject, body
      end

      def self.reset_password(user, token)
        ui_name = LinkedData.settings.ui_name
        subject = "[#{ui_name}] User #{user.username} password reset"
        password_url = "https://#{LinkedData.settings.ui_host}/reset_password?tk=#{token}&em=#{CGI.escape(user.email)}&un=#{CGI.escape(user.username)}"

        body =  REST_PASSWORD.gsub('%ui_name%', ui_name)
                             .gsub('%username%', user.username.to_s)
                             .gsub('%password_url%', password_url.to_s)

        Notifier.notify_mails_separately subject, body, [user.email]
      end

      def self.obofoundry_sync(missing_onts, obsolete_onts)
        body = ''
        ui_name = LinkedData.settings.ui_name
        if missing_onts.size > 0
          body << "<strong>The following OBO Library ontologies are missing from #{ui_name}:</strong><br/><br/>"
          missing_onts.each do |ont|
            body << "<a href='#{ont['homepage']}'>#{ont['id']}</a> (#{ont['title']})<br/><br/>"
          end
        end

        if obsolete_onts.size > 0
          body << '<strong>The following OBO Library ontologies have been deprecated:</strong><br/><br/>'
          obsolete_onts.each do |ont|
            body << "<a href='#{ont['homepage']}'>#{ont['id']}</a> (#{ont['title']})<br/><br/>"
          end
        end

        if body.empty?
          body << "#{ui_name} and the OBO Foundry are in sync.<br/><br/>"
        end

        Notifier.notify_mails_separately subject, body, [LinkedData.settings.email_sender]
      end

      NEW_NOTE = <<EOS
A new note was added to %ontologies% by <b>%username%</b>.<br/><br/>

----------------------------------------------------------------------------------<br/>
<b>Subject:</b> %note_subject%<br/><br/>

%note_body%<br/>
----------------------------------------------------------------------------------<br/><br/>

You can respond by visiting: <a href="%note_url%">%ui_name%</a>.<br/><br/>
EOS

      SUBMISSION_PROCESSED = <<EOS
%ontology_name% (%ontology_acronym%) was processed for use in %ui_name%. Here are the results:
<br><br>
%statuses%
<br><br>
Please contact %admin_email% if you have questions.
<br><br>
The ontology can be <a href="%ontology_location%">browsed in %ui_name%</a>.
<br><br>
Thank you,<br>
The %ui_name% Team
EOS

      SUBMISSION_METADATA_ONLY = <<EOS
%ontology_name% (%ontology_acronym%) was saved in %ui_name% as a metadata-only submission.
<br><br>
No ontology file was provided, so there was nothing to parse: this is expected for a metadata-only submission.
If you have the ontology file, you can add it by submitting a new version: <a href="%new_version_url%">Add a new version</a>.
<br><br>
%recommended%Please contact %admin_email% if you have questions.
<br><br>
The ontology can be <a href="%ontology_location%">browsed in %ui_name%</a>.
<br><br>
Thank you,<br>
The %ui_name% Team
EOS

      RECOMMENDED_EMPTY = <<EOS
%count% recommended metadata %fields% still empty: <a href="%edit_url%">complete the metadata</a>.
<br><br>
EOS

      REMOTE_PULL_FAILURE = <<EOS
%ui_name% failed to load %ont_name% (%ont_acronym%) from URL: %ont_pull_location%.
<br><br>
Please verify the URL you provided for daily loading of your ontology:
<ol>
<li>Make sure you are signed in to %ui_name%.</li>
<li>Navigate to your ontology summary page: <a href="%ontology_location%">%ontology_location%</a>.</li>
<li>Click the &quot;Edit submission information&quot; link.</li>
<li>In the Location row, verify that you entered a valid URL for daily loading of your ontology in the URL text area.</li>
</ol>
If you need further assistance, please <a href="mailto:%support_mail%">contact us</a> via the %ui_name% support mailing list.
<br><br>
Thank you,<br>
The %ui_name% Team
EOS

      NEW_USER_CREATED = <<EOS
A new user have been created on %site_url%
<br>
Username: %username%
<br>
Email: %email%
<br><br>
The %ui_name% Team
EOS

      NEW_ONTOLOGY_CREATED = <<EOS
A new ontology have been created by %addedby% on %site_url%
<br>
Acronym: %acronym%
<br>
Name: %name%
<br>
At <a href="%ont_url%">%ont_url%</a>
<br><br>
The %ui_name% Team
EOS

      REST_PASSWORD = <<~HTML
        Someone has requested a password reset for user %username% . If this was
        you, please click on the link below to reset your password. Otherwise, please
        ignore this email.<br/><br/>

        <a href="%password_url%">%password_url%</a><br/><br/>

        Thanks,<br/>
        %ui_name% Team
HTML

    end
  end
end

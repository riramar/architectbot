package LinuxAjuda;
# VERSAO: 1.0
use URLHelper;
use LWP::UserAgent;

sub search {
  my $pesquisa = shift; 

  my $primariofound=0;
  my @primario;
  my @saida;

  my $URL = "http://www.linuxajuda.com.br/procura.php?p=".URLHelper::urlencode($pesquisa);
  my $ua = new LWP::UserAgent;
  $ua->timeout(30);
  $ua->agent("AgentName/0.1 " . $ua->agent);
  my $req = new HTTP::Request POST => $URL;
  $req->content_type('application/x-www-form-urlencoded');
  my $res = $ua->request($req);
  if ($res->is_success) {
    my $content = $res->content;
    @saida=&output_wiki_status($content);
  }
  if ($#saida >= 0) {
    for (@saida) {
      if ($_ =~ /\b$pesquisa\b/i) {
        $primario[$#primario + 1]=$_;
        $primariofound=1;
      }
    }

    my $numero=int rand($#saida + 1);
    my $message_resp="(LinuxAjuda): ".$saida[$numero];
    if ($primariofound == 1) {
      my $numero=int rand($#primario + 1);
      $message_resp="(LinuxAjuda): $primario[$numero]";
    }
    if ($#saida >= 1) {
      $message_resp.=" (+".($#saida)." docs)";
    }
    return $message_resp;
  }
  return;
}

sub output_wiki_status {
  my (@messages) = @_;
  my $status=0;
  my ($message, $line, @lines, @saida);
  my ($titulo, $url); 
  foreach $line (@messages) {
    @lines=split(/\n/, $line);
    for(@lines) {
      #print "M: $_\n";
      $message=$_;
      chomp($message);
      if ($message =~ /<a href=\"(texto\.php\?id=.*)\">(.*)<\/a>/i) {
        $titulo=$2;
	$url=$1;
	$titulo=~s/<b>|<\/b>//gi;
	$url=~s/<b>|<\/b>//gi;
        $saida[$#saida + 1]="$titulo - http://www.linuxajuda.com.br/$url";
      }
    }
  }  
  return @saida;
}

1;

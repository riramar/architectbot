#!/usr/bin/perl -W

use Net::IRC;
use DBI;
#use LinuxAjuda;
use strict;

my $i;
my @row;
my %usercola;
my $temposec;
my $tempomin;
my $rankcola;
my $key;
my $mascara;

my $irc = new Net::IRC;
my $server   = 'sp.brasnet.org';
my $port     = '6667';
my $botnick  = 'Architect';
my $botpass  = 'mameluco';
my $ircname  = 'Architect';
my $username = 'Architect';
my $channel  = '#linuxajuda';
my $logdir   = '/home/ircbot/Architect/logs/';

my $dsn = 'dbi:mysql:Architect:localhost:3306';
my $mysqluser = 'Architect';
my $mysqlpass = 'mameluco';
my $dbh = DBI->connect($dsn, $mysqluser, $mysqlpass) or die "Nao foi possivel conectar ao DB: $DBI::errstr\n";
#$dbh->disconnect or warn "Falha ao disconectar: $DBI::errstr\n";

sub log_chan {
    my ( $chan, $textlog ) = @_;
    open( LOG, ">>$logdir$chan.log");
    my $time = sprintf( "%02d:%02d:%02d", ( localtime( time() ) )[ 2, 1, 0 ] );
    print LOG "[$time] $textlog\n";
    close (LOG);
}

print "Iniciando conexao com $server:$port ...\n";
my $self = $irc->newconn(
    Server	=> $server,
    Port	=> $port, 
    Nick	=> $botnick,
    Ircname	=> $ircname,
    Username	=> $username
);
print "Conexao concluida!\n";

sub on_connect {
    my $self = shift;
    $self->sl("NickServ IDENTIFY $botpass");
    $self->join($channel);
}

sub on_join {
    my ($self, $event) = @_;
    my $nick = $event->{nick};
    log_chan($channel, "Join: $nick");
}

sub on_part {
    my ($self, $event) = @_;
    my $nick = $event->{nick};
    log_chan($channel, "Part: $nick");
}

sub on_msg {
    my ($self, $event) = @_;
    my $nick = $event->nick;
    my $text = $event->{args}[0];
    if ($text eq "!lista") {
	for $key (keys(%usercola)) {
    	    $self->privmsg($nick, "$key $usercola{$key}");
	}
    }    
}

sub on_public {
    my ($self, $event) = @_;
    my $nick = $event->{nick};
    my $text = $event->{args}[0];
#    log_chan($event->{to}[0], "<$nick> $text");
    log_chan($channel, "<$nick> $text");

    if ($text eq "!ajuda") {
	$self->privmsg($nick, "Estamos implementando uma nova maneira de melhor o canal $channel por meio de votacao dos nossos colaboradores.");
	$self->privmsg($nick, "A ideia e montar um ranking dos colaboradores mais ativos para incentivar os usuarios colaboradores.");
	$self->privmsg($nick, "Para saber a lista de comandos digite \"!comandos\" no canal $channel.");
	$self->privmsg($nick, "Se voce quer ser um colaborador ou a pessoa que lhe ajudou nao esta na lista de colaboradores envie um e-mail para agent_smith\@linxuajuda.com.br ou um memo para Agent_Smith com o seu nick, nome e e-mail.");
    }

    if ($text eq "!comandos") {
	$self->privmsg($nick, "Lista de comandos:");
	$self->privmsg($nick, "!colaboradores (Lista todos os colaboradores do canal $channel)");
	$self->privmsg($nick, "!rank x (Lista os x primeiros do ranking do canal $channel)");
	$self->privmsg($nick, "!voto nick x (Vota x pontos no colaborador nick do canal $channel)");
    }

    if ($text eq "!colaboradores") {
	$self->privmsg($nick, "Lista dos colaboradores do canal $channel:");
	my $sth = $dbh->prepare("SELECT Nick, Nome FROM Colaboradores");
	$sth->execute;
	while(@row = $sth->fetchrow_array()) {
	    $self->privmsg($nick, "$row[0] ($row[1])");
	}
    }

    if ($text eq "!rank") {
	$self->privmsg($channel, "$nick: Informe a quantidade de colaboradores (ex. !rank 5).");
    } elsif ($text =~ /^\!rank (.+)/) {
	$rankcola = $1;
	if ($rankcola =~ /^-?\d/) {
		my $sth = $dbh->prepare("SELECT * FROM Colaboradores ORDER BY Pontos DESC LIMIT $rankcola");
	        $sth->execute;
	    if ($rankcola == 1) {
		@row = $sth->fetchrow_array();
		$self->privmsg($channel, "nick: $row[0] e o primeiro colocado no ranking do canal $channel!");
	    } else {
		$self->privmsg($nick, "Ranking dos $rankcola primeiros colaboradores do canal $channel:");
		$i = 1;
	        while(@row = $sth->fetchrow_array()) {
	    	    $self->privmsg($nick, "$i $row[0] : $row[3]");
		    $i++;
		}
	    }
	} else {
	    $self->privmsg($nick, "$nick: A quantidade de colaboradores precisa ser numerica (ex. !rank 5).");
	}
    }

    if ($text =~ /^\!voto (.+) (.+)/) {
	my $sth = $dbh->prepare("SELECT * FROM Colaboradores WHERE Nick='$1'");
	$sth->execute;
	my $rv = $sth->rows;
        if ($rv == 0) {
	    $self->privmsg($channel, "$nick: O colaborador $1 nao esta cadastrado. Para cadastralo envie um e-mail para agent_smith\@linxuajuda.com.br ou um memo para Agent_Smith com o seu nick, nome e e-mail.");
	    log_chan($channel, "<$botnick> $nick: O colaborador $1 nao esta cadastrado. Para cadastralo envie um e-mail para agent_smith\@linxuajuda.com.br ou um memo para Agent_Smith com o seu nick, nome e e-mail.");
	} elsif ($2 =~ /[^0-9-]/) {
	    $self->privmsg($channel, "$nick: A pontuacao deve ser numerica.");
	    log_chan($channel, "<$botnick> $nick: A pontuacao deve ser numerica.");
	} elsif ($2 < 1 || $2 > 5 ) {
	    $self->privmsg($channel, "$nick: A pontuacao deve estar entre 1 e 5.");
	    log_chan($channel, "<$botnick> $nick: A pontuacao deve estar entre 1 e 5.");
	} elsif ($1 eq $nick ) {
	    $self->privmsg($channel, "$nick: Voce quer votar em voce mesmo?");
	    log_chan($channel, "<$botnick> $nick: Voce quer votar em voce mesmo?");
	} else {
	    $mascara = $event->userhost;
	    if ( defined($usercola{"$mascara $1"}) && ($usercola{"$mascara $1"} > (time() - 1800)) ) {
		$temposec = 1800 - (time() - $usercola{"$mascara $1"});
		$tempomin = int($temposec / 60);
		$temposec = $temposec % 60;
	        $self->privmsg($channel, "$nick: Voce so podera votar em $1 novamente em $tempomin minuto(s) e $temposec segundo(s).");
		log_chan($channel, "<$botnick> $nick: Voce so podera votar em $1 novamente em $tempomin minuto(s) e $temposec segundo(s).");
	    } else {
		$usercola{"$mascara $1"} = time();
		my $sth = $dbh->prepare("UPDATE Colaboradores SET Pontos=Pontos+$2 WHERE Nick='$1'");
	        $sth->execute;
	        $self->privmsg($channel, "$nick: $2 ponto(s) registrado para $1.");
		log_chan($channel, "<$botnick> $nick: $2 ponto(s) registrado para $1.");
	    }
	}
    }

}

sub on_quit {
    my ($self, $event) = @_;
    my $nick = $event->{nick};
    my $text = $event->{args}[0];
    log_chan($channel, "Quit: $text [$nick]");
}

$SIG{ALRM} = 'msg_canal';
my $intervalo = 1800;
alarm $intervalo;
sub msg_canal
{
    alarm $intervalo;
    $self->privmsg($channel, "Voce foi ajudado ou quer ajudar o canal? Digite: !ajuda");

    for $key (keys(%usercola)) {
	if ( defined($usercola{$key}) && ($usercola{$key} < (time() - 1800)) ) {
	    delete $usercola{$key};
	}
    }
}

$self->add_handler('join', \&on_join);
$self->add_handler('part', \&on_part);
$self->add_handler('msg', \&on_msg);
$self->add_handler('public', \&on_public);
$self->add_handler('quit', \&on_quit);
$self->add_handler('376', \&on_connect);

$irc->start();